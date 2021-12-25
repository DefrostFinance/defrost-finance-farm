/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2020 defrost Protocol
 */
pragma solidity ^0.5.16;

import "../modules/SafeMath.sol";
import "../modules/proxyOwner.sol";
import "../modules/IERC20.sol";
import "../modules/SafeERC20.sol";
import "./smeltSavingsData.sol";
import "./smeltToken/smeltToken.sol";
/**
 * @title systemCoin deposit pool.
 * @dev Deposit systemCoin earn interest systemcoin.
 *
 */
contract smeltSavings is smeltSavingsData,proxyOwner{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    /**
     * @dev default function for foundation input miner coins.
     */
    constructor (address _melt,
                 address _multiSignature,
                 address _origin0,
                 address _origin1)
       proxyOwner(_multiSignature,_origin0,_origin1)
       public
    {
        melt = _melt;
        smelt = new smeltToken("Defrost Finance Smelt Token","SMELT",18,address(this));
    }

    function () external payable{
        require(false);
    }

    function setInterestMaxMinRatio(uint256 _maxRate, uint256 _minRate)
        external
        onlyOrigin {
        maxRate = _maxRate;
        minRate = _minRate;
    }

    function setInterestInfo(int256 _interestRate,uint256 _interestInterval)
        external
        onlyOrigin
    {

        if (accumulatedRate == 0){
            accumulatedRate = rayDecimals;
        }

        require(_interestRate<=1e27 && _interestRate>=-1e27,"input stability fee is too large");
        require(_interestInterval>0,"input mine Interval must larger than zero");

        uint256 newLimit = rpower(uint256(1e27+_interestRate),/*one year*/31536000/_interestInterval,rayDecimals);
        require(newLimit<=maxRate && newLimit>=minRate,"interest rate is out of range");

        _interestSettlement();

        interestRate = _interestRate;
        interestInterval = _interestInterval;

        emit SetInterestInfo(msg.sender,_interestRate,_interestInterval);
    }

    function newAccumulatedRate() internal view returns (uint256){
        uint256 newRate = rpower(uint256(1e27+interestRate),(currentTime()-latestSettleTime)/interestInterval,rayDecimals);
        return accumulatedRate.mul(newRate)/rayDecimals;
    }

    function currentTime() internal view returns (uint256){
        return block.timestamp;
    }

    function _interestSettlement() internal {
        uint256 _interestInterval = interestInterval;
        if (_interestInterval>0){
            uint256 newRate = newAccumulatedRate();
            accumulatedRate = newRate;
            latestSettleTime = currentTime()/_interestInterval*_interestInterval;
        }else{
            latestSettleTime = currentTime();
        }
    }

    function getMeltAmount(uint256 _smeltAmount) public view returns (uint256) {
        uint256 newRate = newAccumulatedRate();
        return _smeltAmount.mul(newRate).div(rayDecimals);
    }

    function deposit(uint256 _amount)
        external
        nonReentrant
        notHalted
    {
        require(interestRate>0,"interest rate is not set");

        IERC20(melt).safeTransferFrom(msg.sender, address(this), _amount);

        _interestSettlement();

        uint256 smeltAmount = _amount.mul(rayDecimals)/accumulatedRate;
        smelt.mint(msg.sender,smeltAmount);

        emit Save(msg.sender,address(melt), _amount);
    }

    //user possible to get smelt by transfer from another address
    function withdraw( uint256 _smeltAmount/*smelt amout*/)
        external
        nonReentrant
        notHalted
    {

        _interestSettlement();
        uint256 smeltbal = IERC20(smelt).balanceOf(msg.sender);
        if(_smeltAmount>smeltbal) {
            _smeltAmount = smeltbal;
        }
        uint256 meltAmount = _smeltAmount.mul(accumulatedRate)/rayDecimals;

        smelt.burn(msg.sender,_smeltAmount);

        IERC20(melt).safeTransfer(msg.sender, meltAmount);

        emit Withdraw(msg.sender,address(melt), meltAmount);

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
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //    /**
    //     * @param addr The user to look up staking information for.
    //     * @return The number of staking tokens deposited for addr.
    //     */
    function totalStakedFor(address _account) public view returns (uint256) {
         return getMeltAmount(smelt.balanceOf(_account));
    }

    function totalStaked() public view returns (uint256){
       return getMeltAmount(smelt.totalSupply());
    }

    function getbackLeftMiningToken(address _reciever)  external
        onlyOrigin
    {

        uint256 totalasset = getMeltAmount(smelt.totalSupply());
        //get back melt for future interest
        if(IERC20(melt).balanceOf(address(this))>totalasset) {
            uint256 bal =  IERC20(melt).balanceOf(address(this)).sub(totalasset);
            IERC20(melt).safeTransfer(_reciever,bal);
        }

    }

}