/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2020 defrost Protocol
 */
pragma solidity ^0.5.16;

import "../modules/ReentrancyGuard.sol";
import "../modules/Halt.sol";

contract PreGenesisData is Halt,ReentrancyGuard {
    bool public allowWithdraw;
    bool public allowDeposit;

    address public coin;
    address public targetSc;
    //Special decimals for calculation
    uint256 constant internal rayDecimals = 1e27;

    uint256 public totalAssetAmount;
    // Maximum amount of debt that can be generated with this collateral type
    uint256 public assetCeiling;       // [rad]
    // Minimum amount of debt that must be generated by a SAFE using this collateral
    uint256 public assetFloor;         // [rad]
    //interest rate
    uint256 internal interestRate;
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

    event SetInterestInfo(address indexed from,uint256 _interestRate,uint256 _interestInterval);
    event AddAsset(address indexed recieptor,uint256 amount);
    event SubAsset(address indexed account,uint256 amount,uint256 subOrigin);

    event InitContract(address indexed sender,address systemCoin,uint256 interestRate,uint256 interestInterval,
        uint256 assetCeiling,uint256 assetFloor);
    event Deposit(address indexed sender, address indexed account, uint256 amount);
    event Withdraw(address indexed sender, address indexed account, uint256 amount);
    event TransferToTarget(address indexed sender, address indexed account, uint256 amount);
}