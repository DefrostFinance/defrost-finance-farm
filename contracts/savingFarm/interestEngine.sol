// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.16;

import "../modules/SafeMath.sol";
/**
 * @title interest engine.
 * @dev calculate interest by assets,compounded interest.
 *
 */
contract interestEngine {
    using SafeMath for uint256;

        //Special decimals for calculation
    uint256 constant internal rayDecimals = 1e27;

    uint256 public totalAssetAmount;
        // Maximum amount of debt that can be generated with this collateral type
    uint256 public assetCeiling;       // [rad]
    // Minimum amount of debt that must be generated by a SAFE using this collateral
    uint256 public assetFloor;         // [rad]
    //interest rate
    int256 internal interestRate;
    uint256 internal interestInterval;
    struct assetInfo{
        uint256 originAsset;
        uint256 assetAndInterest;
        uint256 interestRateOrigin;
    }
    // debt balance
    mapping(address=>assetInfo) public assetInfoMap;

        // latest time to settlement
    uint256 internal latestSettleTime;
    uint256 internal accumulatedRate;

    event SetInterestInfo(address indexed from,int256 _interestRate,uint256 _interestInterval);
    event AddAsset(address indexed recieptor,uint256 amount);
    event SubAsset(address indexed account,uint256 amount,uint256 subOrigin);
    /**
     * @dev retrieve Interest informations.
     * @return distributed Interest rate and distributed time interval.
     */
    function getInterestInfo()external view returns(int256,uint256){
        return (interestRate,interestInterval);
    }

    /**
     * @dev Set mineCoin mine info, only foundation owner can invoked.
     * @param _interestRate mineCoin distributed amount
     * @param _interestInterval mineCoin distributied time interval
     */
    function _setInterestInfo(int256 _interestRate,uint256 _interestInterval,uint256 maxRate,uint256 minRate)internal {
        if (accumulatedRate == 0){
            accumulatedRate = rayDecimals;
        }
        require(_interestRate<=1e27 && _interestRate>=-1e27,"input stability fee is too large");
        require(_interestInterval>0,"input mine Interval must larger than zero");
        uint256 newLimit = rpower(uint256(1e27+_interestRate),31536000/_interestInterval,rayDecimals);

        require(newLimit<=maxRate && newLimit>=minRate,"input stability fee is out of range");
        _interestSettlement();
        interestRate = _interestRate;
        interestInterval = _interestInterval;
        emit SetInterestInfo(msg.sender,_interestRate,_interestInterval);
    }

    function getAssetBalance(address account) public view returns(uint256){
        if(assetInfoMap[account].interestRateOrigin == 0 || interestInterval == 0){
            return 0;
        }
        uint256 newRate = newAccumulatedRate();
        return assetInfoMap[account].assetAndInterest.mul(newRate)/assetInfoMap[account].interestRateOrigin;
    }

    /**
     * @dev mint mineCoin to account when account add collateral to collateral pool, only manager contract can modify database.
     * @param account user's account
     * @param amount the mine shared amount
     */
    function addAsset(address account,uint256 amount) internal settleAccount(account){
        assetInfoMap[account].originAsset = assetInfoMap[account].originAsset.add(amount);
        assetInfoMap[account].assetAndInterest = assetInfoMap[account].assetAndInterest.add(amount);
        totalAssetAmount = totalAssetAmount.add(amount);
        require(assetInfoMap[account].assetAndInterest >= assetFloor, "Debt is below the limit");
        require(totalAssetAmount <= assetCeiling, "vault debt is overflow");
        emit AddAsset(account,amount);
    }
    /**
     * @dev repay user's debt and taxes.
     * @param amount repay amount.
     */
    function subAsset(address account,uint256 amount) internal returns(uint256) {
        uint256 originBalance = assetInfoMap[account].originAsset;
        uint256 assetAndInterest = assetInfoMap[account].assetAndInterest;
        
        uint256 _subAsset;
        if(assetAndInterest == amount){
            _subAsset = originBalance;
            assetInfoMap[account].originAsset = 0;
            assetInfoMap[account].assetAndInterest = 0;
        }else if(assetAndInterest > amount){
            _subAsset = originBalance.mul(amount)/assetAndInterest;
            assetInfoMap[account].assetAndInterest = assetAndInterest.sub(amount);
            require(assetInfoMap[account].assetAndInterest >= assetFloor, "Debt is below the limit");
            assetInfoMap[account].originAsset = originBalance.sub(_subAsset);

        }else{
            require(false,"overflow asset balance");
        }
        totalAssetAmount = totalAssetAmount.sub(amount);
        emit SubAsset(account,amount,_subAsset);
        return _subAsset;
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
    function _interestSettlement() internal {
        uint256 _interestInterval = interestInterval;
        if (_interestInterval>0){
            uint256 newRate = newAccumulatedRate();
            totalAssetAmount = totalAssetAmount.mul(newRate)/accumulatedRate;
            accumulatedRate = newRate;
            latestSettleTime = currentTime()/_interestInterval*_interestInterval;
        }else{
            latestSettleTime = currentTime();
        }
    }

    function newAccumulatedRate()internal view returns (uint256){
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
    function _settlement(address account)internal view returns (uint256) {
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