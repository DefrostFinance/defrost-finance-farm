/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2020 defrost Protocol
 */
pragma solidity ^0.5.16;

import "../modules/ReentrancyGuard.sol";
import "../modules/Halt.sol";
import "./interestEngine.sol";
import "./TokenFarm.sol";

contract savingsPoolData is Halt,interestEngine,ReentrancyGuard {
    uint256 constant internal currentVersion = 1;
    address  public melt;
    address  public h2o;
    TokenFarm public tokenFarm;

    event InitContract(address indexed sender,address systemCoin,int256 interestRate,uint256 interestInterval,
        uint256 assetCeiling,uint256 assetFloor);
    event Save(address indexed sender, address indexed account, uint256 amount);
    event Withdraw(address indexed sender, address indexed account, uint256 amount);
}