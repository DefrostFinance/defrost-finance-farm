const { time, expectEvent} = require("@openzeppelin/test-helpers");
const PreGenesis = artifacts.require('PreGenesis');
const USDCToken = artifacts.require('LpToken');
const Oracle = artifacts.require('Oracle');
const MultiSignature = artifacts.require("multiSignature");
const assert = require('chai').assert;
const Web3 = require('web3');
const BN = require("bignumber.js");
var utils = require('../utils.js');

web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/
// 现在一般都是1个小时结息一次，
// 计算器算一下,
//     _interestRate = (1.05)^(1/24)-1,decimals=27，_interestInterval = 3600
//
// 1.0020349912970346474243981869599-1 = 0.0020349912970346474243981869599，再*1e27就行了
let YEAR_INTEREST = new BN("0.6");
let DAY_INTEREST = YEAR_INTEREST.div(new BN(365));//日利息 5%0
//let DAY_INTEREST = new BN(0.005);
let INTEREST_RATE = new BN("1").plus(new BN(DAY_INTEREST));
let DIV24= new BN("1").div(24);//div one day 24 hours
INTEREST_RATE = Math.pow(INTEREST_RATE,DIV24) - 1;

console.log("INTEREST_RATE",INTEREST_RATE);
INTEREST_RATE = new BN(INTEREST_RATE).times(new BN("1000000000000000000000000000"));

console.log("INTEREST_RATE "+INTEREST_RATE.toString(10));
//return;

contract('PreGenesis', function (accounts){

  let stakeAmount = web3.utils.toWei('10', 'ether');
  let startBlock = 0;

  let staker1 = accounts[2];
  let staker2 = accounts[3];

  let teamMember1 = accounts[4];
  let teamMember2 = accounts[5];
  let teammems = [teamMember1,teamMember2];
  let teammemsRatio = [20,80];

  let operator0 = accounts[7];
  let operator1 = accounts[8];

  let mocksc = accounts[9];

  let disSpeed1 = web3.utils.toWei('1', 'ether');

  let VAL_1M = web3.utils.toWei('1000000', 'ether');
  let VAL_10M = web3.utils.toWei('10000000', 'ether');
  let VAL_100M = web3.utils.toWei('100000000', 'ether');
  let VAL_1B = web3.utils.toWei('1000000000', 'ether');
  let VAL_10B = web3.utils.toWei('10000000000', 'ether');

  let minutes = 60;
  let hour    = 60*60;
  let eightHour = 8*hour;
  let day     = 24*hour;
  let totalPlan  = 0;

  let preGenesisinst;

  let usdc;//stake token

  let mulSiginst;
  let oracleinst;


  before("init", async()=>{

  oracleinst = await Oracle.new();
  await oracleinst.setOperator(3,accounts[0]);

   //setup multisig
  let addresses = [accounts[7],accounts[8],accounts[9]];
  mulSiginst = await MultiSignature.new(addresses,0,{from : accounts[0]});
  console.log(mulSiginst.address);
//////////////////////LP POOL SETTING///////////////////////////////////////////////////
  usdc = await USDCToken.new("USDC",6);
  await usdc.mint(staker1,VAL_10M);
  await usdc.mint(staker2,VAL_10M);

//set phxfarm///////////////////////////////////////////////////////////
  preGenesisinst = await PreGenesis.new(mulSiginst.address,operator0,operator1,usdc.address,mocksc);
  console.log("pregenesis address:", preGenesisinst.address);


  let block = await web3.eth.getBlock("latest");
  startTime = block.timestamp + 1000;
  console.log("set block time",startTime);

  let endTime = startTime + 3600*24*365;

      // function initContract(uint256 _interestRate,uint256 _interestInterval,
      //     uint256 _assetCeiling,uint256 _assetFloor)
//////////////////////////////////////////////////////////////////////////////////////////
  {
      let msgData = preGenesisinst.contract.methods.initContract(INTEREST_RATE.toString(10),eightHour,VAL_10M,0).encodeABI();
      let hash = await utils.createApplication(mulSiginst, operator0, preGenesisinst.address, 0, msgData);
      let index = await mulSiginst.getApplicationCount(hash);
      index = index.toNumber() - 1;
      console.log(index);

      await mulSiginst.signApplication(hash, index, {from: accounts[7]});
      await mulSiginst.signApplication(hash, index, {from: accounts[8]});
  }
      //set interest rate
      res = await preGenesisinst.initContract(INTEREST_RATE,eightHour,VAL_10M,0,{from:operator0});
      assert.equal(res.receipt.status,true);

      {
          let msgData = preGenesisinst.contract.methods.setDepositStatus(true).encodeABI();
          let hash = await utils.createApplication(mulSiginst, operator0, preGenesisinst.address, 0, msgData);
          let index = await mulSiginst.getApplicationCount(hash);
          index = index.toNumber() - 1;
          console.log(index);

          await mulSiginst.signApplication(hash, index, {from: accounts[7]});
          await mulSiginst.signApplication(hash, index, {from: accounts[8]});
      }
      res = await preGenesisinst.setDepositStatus(true,{from:operator0});
      assert.equal(res.receipt.status,true);
  })

  it("[0010] stake in,should pass", async()=>{
    time.increase(7200);//2000 sec
    ////////////////////////staker1///////////////////////////////////////////////////////////
    let res = await usdc.approve(preGenesisinst.address,VAL_1M,{from:staker1});
    assert.equal(res.receipt.status,true);
    time.increase(1000);

    res = await preGenesisinst.deposit(VAL_1M,{from:staker1});
    assert.equal(res.receipt.status,true);

    time.increase(day+1);

    res = await preGenesisinst.getBalance(staker1);
    console.log(res[0].toString(),res[1].toString());

    await usdc.approve(preGenesisinst.address,VAL_1M,{from:staker1});
    res = await preGenesisinst.deposit(VAL_1M,{from:staker1});
    assert.equal(res.receipt.status,true);

    res = await preGenesisinst.getBalance(staker1);
    console.log(res[0].toString(),res[1].toString());
  })

/*
  it("[0030] stake out,should pass", async()=>{
        console.log("\n\n");
        let preLpBlance = await melt.balanceOf(staker1);
        console.log("preLpBlance=" + preLpBlance);

        let preStakeBalance = await farminst.totalStakedFor(staker1);
        preStakeBalance = (new BN(preStakeBalance.toString(10)).div(new BN(2))).integerValue();

        console.log("pre sc staked for= " + preStakeBalance);

        let res = await farminst.withdraw(preStakeBalance,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterStakeBalance = await farminst.totalStakedFor(staker1);

        console.log("after sc staked for = " + afterStakeBalance);

        let diff = web3.utils.fromWei(new BN(preStakeBalance).toString(10)) - web3.utils.fromWei(afterStakeBalance);
        console.log("stake balance diff = " + diff);

        let afterLpBlance = await melt.balanceOf(staker1);
        console.log("afterLpBlance=" + afterLpBlance);
        let lpdiff = web3.utils.fromWei(afterLpBlance) - web3.utils.fromWei(preLpBlance);

        console.log("staked balance "+diff,"lp balance change ="+lpdiff);

        //assert.equal(lpdiff,web3.utils.fromWei(VAL_1M));
    })



    it("[0050] get back left mining token,should pass", async()=>{

            let msgData = farminst.contract.methods.getbackLeftMiningToken(staker1).encodeABI();
            let hash = await utils.createApplication(mulSiginst,operator0,farminst.address,0,msgData);

            let res = await utils.testSigViolation("multiSig getbackLeftMiningToken: This tx is not aprroved",async function(){
                await farminst.getbackLeftMiningToken(staker1,{from:operator0});
            });
            assert.equal(res,false,"should return false")

            let index = await mulSiginst.getApplicationCount(hash);
            index = index.toNumber()-1;
            console.log(index);

            await mulSiginst.signApplication(hash,index,{from:accounts[7]})
            await mulSiginst.signApplication(hash,index,{from:accounts[8]})


            console.log("\n\n");
            let h2opreMineBlance = await h2o.balanceOf(staker1);
            console.log("h2o preMineBlance=" + h2opreMineBlance);

            let meltpreRecieverBalance = await melt.balanceOf(staker1);
            console.log("melt prebalance = " + meltpreRecieverBalance);

            // res = await proxy.getbackLeftMiningToken(staker1,{from:accounts[9]});
            // assert.equal(res.receipt.status,true);
            res = await utils.testSigViolation("multiSig getback reward token: This tx is aprroved",async function(){
                await farminst.getbackLeftMiningToken(staker1,{from:operator0});
            });
            assert.equal(res,true,"should return false")

            let h2oafterRecieverBalance = await  h2o.balanceOf(staker1);
            console.log("after h2o mine balance = " + h2oafterRecieverBalance);

            let meltafterRecieverBalance = await  melt.balanceOf(staker1);
            console.log("after melt mine balance = " + meltafterRecieverBalance);

            let diff = web3.utils.fromWei(h2oafterRecieverBalance) - web3.utils.fromWei(h2opreMineBlance);
            console.log("h2o getback balance = " + diff);

            diff = web3.utils.fromWei(meltafterRecieverBalance) - web3.utils.fromWei(meltpreRecieverBalance);
            console.log("melt getback balance = " + diff);

        })


    it("[0070] staker2 stake out all,should pass", async()=>{
        time.increase(200);//2000 sec
        console.log("\n\n");
        let preLpBlance = await melt.balanceOf(staker2);
        console.log("preLpBlance=" + preLpBlance);

        let preStakeBalance = await farminst.totalStakedFor(staker2);
        console.log("pre sc staked for= " + preStakeBalance);

        let res = await farminst.withdraw(new BN("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",16),{from:staker2});
        console.log(res);

        assert.equal(res.receipt.status,true);

        let afterStakeBalance = await farminst.totalStakedFor(staker2);

        console.log("after sc staked for = " + afterStakeBalance);

        let diff = web3.utils.fromWei(preStakeBalance) - web3.utils.fromWei(afterStakeBalance);
        console.log("stake balance diff = " + diff);

        let afterLpBlance = await melt.balanceOf(staker2);
        console.log("afterLpBlance=" + afterLpBlance);
        let lpdiff = web3.utils.fromWei(afterLpBlance) - web3.utils.fromWei(preLpBlance);

        console.log("staked balance "+diff,"lp balance change ="+lpdiff);

        assert.equal(lpdiff>=web3.utils.fromWei(VAL_1M),true);
    })
*/

})