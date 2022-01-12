// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.5.16;

import "../modules/SafeMath.sol";
import "../modules/proxyOwner.sol";
import "../modules/IERC20.sol";
import "../modules/SafeERC20.sol";

import "./PreGenesisData.sol";

/**
 * @title interest engine.
 * @dev calculate interest by assets,compounded interest.
 *
 */
contract PreGenesis is PreGenesisData,proxyOwner{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    /**
     * @dev default function for foundation input miner coins.
     */
    constructor (address multiSignature,address origin0,address origin1)
        proxyOwner(multiSignature,origin0,origin1)
    public {

    }

    function initContract(address _coin,uint256 _interestRate,uint256 _interestInterval,
        uint256 _assetCeiling,uint256 _assetFloor)external originOnce{
        coin = _coin;
        assetCeiling = _assetCeiling;
        assetFloor = _assetFloor;
        _setInterestInfo(_interestRate,_interestInterval,12e26,rayDecimals);

        allowWithdraw = false;
        allowDeposit = false;

        emit InitContract(msg.sender, _coin,_interestRate,_interestInterval,_assetCeiling,_assetFloor);
    }

    function setPoolLimitation(uint256 _assetCeiling,uint256 _assetFloor)external onlyOrigin{
        assetCeiling = _assetCeiling;
        assetFloor = _assetFloor;
    }

    function setInterestInfo(uint256 _interestRate,uint256 _interestInterval)external onlyOrigin{
        _setInterestInfo(_interestRate,_interestInterval,12e26,rayDecimals);
    }

    function setWithdrawStatus(bool _enable)external onlyOrigin{
       allowWithdraw = _enable;
    }

    function setDepositStatus(bool _enable)external onlyOrigin{
        allowDeposit = _enable;
    }

    function deposit(uint256 amount) notHalted nonReentrant settleAccount(msg.sender) external{
        require(allowDeposit,"deposit is not allowed!");
        require(totalAssetAmount < assetCeiling, "asset is overflow");

        if(totalAssetAmount.add(amount)>assetCeiling) {
            amount = assetCeiling.sub(totalAssetAmount);
        }
        IERC20(coin).safeTransferFrom(msg.sender, address(this), amount);

        addAsset(msg.sender,amount);
        emit Deposit(msg.sender,msg.sender,amount);
    }

    function transferVCoin(uint256 amount)
        notHalted
        nonReentrant
        settleAccount(targetSc)
        external
    {
        subAsset(msg.sender,amount);
        addAsset(targetSc, amount);
    }

    function withdraw()
         notHalted
         nonReentrant
         settleAccount(msg.sender)
         external
    {
        require(allowWithdraw,"withdraw is not allowed!");

        uint256 amount = assetInfoMap[msg.sender].originAsset;
        subAsset(msg.sender,amount);
        IERC20(coin).safeTransfer(msg.sender, amount);
        emit Withdraw(coin,msg.sender,amount);
    }

    function TransferCoinToTarget() public onlyOrigin {
        uint256 coinBal = IERC20(coin).balanceOf(address(this));
        IERC20(coin).safeTransfer(targetSc, coinBal);
        emit TransferToTarget(msg.sender,targetSc,coinBal);
    }

    function getVCoinBalance(address account)public view returns(uint256){
        if(assetInfoMap[account].interestRateOrigin == 0 || interestInterval == 0){
            return 0;
        }
        uint256 newRate = newAccumulatedRate();
        return assetInfoMap[account].assetAndInterest.mul(newRate)/assetInfoMap[account].interestRateOrigin;
    }

    function getInterestInfo()external view returns(uint256,uint256){
        return (interestRate,interestInterval);
    }

    function _setInterestInfo(uint256 _interestRate,uint256 _interestInterval,uint256 maxRate,uint256 minRate) internal {
        if (accumulatedRate == 0){
            accumulatedRate = rayDecimals;
        }
        require(_interestRate<=1e27,"input stability fee is too large");
        require(_interestInterval>0,"input mine Interval must larger than zero");
        uint256 newLimit = rpower(uint256(1e27+_interestRate),31536000/_interestInterval,rayDecimals);
        require(newLimit<=maxRate && newLimit>=minRate,"input rate is out of range");
        _interestSettlement();
        interestRate = _interestRate;
        interestInterval = _interestInterval;
        emit SetInterestInfo(msg.sender,_interestRate,_interestInterval);
    }


    function addAsset(address account,uint256 amount) internal /*settleAccount(account)*/{
        assetInfoMap[account].originAsset = assetInfoMap[account].originAsset.add(amount);
        assetInfoMap[account].assetAndInterest = assetInfoMap[account].assetAndInterest.add(amount);
        totalAssetAmount = totalAssetAmount.add(amount);
        emit AddAsset(account,amount);
    }

    function subAsset(address account,uint256 amount) internal {
       require(amount<=assetInfoMap[account].assetAndInterest,"amount is bigger than vCoin");
       assetInfoMap[account].assetAndInterest = assetInfoMap[account].assetAndInterest.sub(amount);
       emit SubAsset(account,amount,amount);
    }


    function rpower(uint256 x, uint256 n, uint256 base) internal pure returns (uint256 z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) { revert(0,0) }
                let xxRound := add(xx, half)
                if lt(xxRound, xx) { revert(0,0) }
                x := div(xxRound, base)
                if mod(n,2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) { revert(0,0) }
                    z := div(zxRound, base)
                }
            }
            }
        }
    }

    /**
     * @dev the auxiliary function for _mineSettlementAll.
     */
    function _interestSettlement()internal{
        uint256 _interestInterval = interestInterval;
        if (_interestInterval>0){
            uint256 newRate = newAccumulatedRate();
            //totalAssetAmount = totalAssetAmount.mul(newRate)/accumulatedRate;
            accumulatedRate = newRate;
            latestSettleTime = currentTime()/_interestInterval*_interestInterval;
        }else{
            latestSettleTime = currentTime();
        }
    }

    function newAccumulatedRate() internal view returns (uint256){
        uint256 newRate = rpower(uint256(1e27+interestRate),(currentTime()-latestSettleTime)/interestInterval,rayDecimals);
        return accumulatedRate.mul(newRate)/rayDecimals;
    }
    /**
     * @dev settle user's debt balance.
     * @param account user's account
     */
    function settleUserInterest(address account)internal{
        assetInfoMap[account].assetAndInterest = _settlement(account);
        assetInfoMap[account].interestRateOrigin = accumulatedRate;
    }
    /**
     * @dev subfunction, settle user's latest tax amount.
     * @param account user's account
     */
    function _settlement(address account) internal view returns (uint256) {
        if (assetInfoMap[account].interestRateOrigin == 0){
            return 0;
        }
        return assetInfoMap[account].assetAndInterest.mul(accumulatedRate)/assetInfoMap[account].interestRateOrigin;
    }

    modifier settleAccount(address account){
        _interestSettlement();
        settleUserInterest(account);
        _;
    }
    
    function currentTime() internal view returns (uint256){
        return block.timestamp;
    }
}