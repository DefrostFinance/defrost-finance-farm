/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2020 defrost Protocol
 */
pragma solidity ^0.5.16;

import "../modules/SafeMath.sol";
import "../modules/proxyOwner.sol";
import "../modules/IERC20.sol";
import "./savingsPoolData.sol";
import "./TokenFarm.sol";
/**
 * @title systemCoin deposit pool.
 * @dev Deposit systemCoin earn interest systemcoin.
 *
 */
contract savingsFarm is savingsPoolData,proxyOwner{
    using SafeMath for uint256;
    /**
     * @dev default function for foundation input miner coins.
     */
    constructor (address multiSignature,
                 address origin0,address origin1)
       proxyOwner(multiSignature,origin0,origin1)
       public
    {

    }

    function initContract(  address _melt,
                            address _h2o,
                            int256 _interestRate,
                            uint256 _interestInterval,
                            uint256 _assetCeiling,
                            uint256 _assetFloor)
      external originOnce
    {
        melt = _melt;
        tokenFarm = new TokenFarm(address(this),_h2o);

        assetCeiling = _assetCeiling;
        assetFloor = _assetFloor;
        _setInterestInfo(_interestRate,_interestInterval,12e26,rayDecimals);

        emit InitContract(msg.sender,_melt,_interestRate,_interestInterval,_assetCeiling,_assetFloor);
    }

    function () external payable{
        require(false);
    }

    function setPoolLimitation(uint256 _assetCeiling,uint256 _assetFloor)external onlyOrigin{
        assetCeiling = _assetCeiling;
        assetFloor = _assetFloor;
    }

    function setInterestInfo(int256 _interestRate,uint256 _interestInterval)external onlyOrigin{
        _setInterestInfo(_interestRate,_interestInterval,12e26,rayDecimals);
    }


    function deposit(uint256 _amount) notHalted nonReentrant settleAccount(msg.sender) external{
        require(IERC20(melt).transferFrom(msg.sender, address(this), _amount),"systemCoin : transferFrom failed!");
        addAsset(msg.sender, _amount);
        //update token mine
        tokenFarm.stake(msg.sender);

        //claim h2o reward while deposit
        tokenFarm.getReward(msg.sender);

        emit Save(msg.sender,address(melt), _amount);
    }

    function withdraw( uint256 amount) notHalted nonReentrant settleAccount(msg.sender) external{
        if(amount == uint256(-1)){
            amount = assetInfoMap[msg.sender].assetAndInterest;
        }

        //updated token mine
        tokenFarm.unstake(msg.sender);

        //claim h2o reward while deposit
        tokenFarm.getReward(msg.sender);

        subAsset(msg.sender,amount);
        require(IERC20(melt).transfer(msg.sender, amount),"systemCoin : transfer failed!");

        emit Withdraw(msg.sender,address(melt),amount);
    }

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //    /**
    //     * @param addr The user to look up staking information for.
    //     * @return The number of staking tokens deposited for addr.
    //     */
    function totalStakedFor(address _account) public view returns (uint256) {
         return assetInfoMap[_account].assetAndInterest;
    }

    function allPendingReward(address _account) public view returns(uint256,uint256){
        uint256 interest = 0;
        if(assetInfoMap[_account].assetAndInterest>assetInfoMap[_account].originAsset) {
            interest = assetInfoMap[_account].assetAndInterest.sub(assetInfoMap[_account].originAsset);
        }

        return (interest,tokenFarm.earned(_account));
    }

    function totalStaked() public view returns (uint256){
       return totalAssetAmount;
    }

    function getbackLeftMiningToken(address _reciever)  public
        onlyOrigin
    {
        tokenFarm.getbackLeftMiningToken(_reciever);
        uint256 bal =  IERC20(melt).balanceOf(address(this));
        IERC20(melt).transferFrom(address(this), _reciever,bal);
    }

    function balanceOf(address _account) external view returns (uint256) {
        return assetInfoMap[_account].assetAndInterest;
    }


}