const { time, expectEvent} = require("@openzeppelin/test-helpers");

const MinePool = artifacts.require('H2oFarmH2oMelt');

const H2oToken = artifacts.require('LpToken');

const Oracle = artifacts.require('Oracle');

const TeamDistribute = artifacts.require('TeamDistribute');
const TeamDistributeProxy = artifacts.require('DefrostTeamDistributeProxy');

const RewardMeltToken = artifacts.require("DefrostToken");
const MultiSignature = artifacts.require("multiSignature");

const assert = require('chai').assert;
const Web3 = require('web3');
const BN = require("bn.js");
var utils = require('../utils.js');
web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/
contract('MinePoolProxy', function (accounts){
  let rewardOneDay = web3.utils.toWei('5000', 'ether');
  let blockSpeed = 5;
  let bocksPerDay = 3600*24/blockSpeed;
  let rewardPerBlock = new BN(rewardOneDay).div(new BN(bocksPerDay));
  console.log(rewardPerBlock.toString(10));

  let stakeAmount = web3.utils.toWei('10', 'ether');
  let startBlock = 0;

  let staker1 = accounts[2];
  let staker2 = accounts[3];

  let teamMember1 = accounts[4];
  let teamMember2 = accounts[5];
  let teammems = [teamMember1,teamMember2];
  let teammemsRatio = [20,80];

  let operator0 = accounts[0];
  let operator1 = accounts[1]

  let disSpeed1 = web3.utils.toWei('1', 'ether');

  let VAL_1M = web3.utils.toWei('1000000', 'ether');
  let VAL_10M = web3.utils.toWei('10000000', 'ether');
  let VAL_100M = web3.utils.toWei('100000000', 'ether');
  let VAL_1B = web3.utils.toWei('1000000000', 'ether');
  let VAL_10B = web3.utils.toWei('10000000000', 'ether');

  let minutes = 60;
  let hour    = 60*60;
  let day     = 24*hour;
  let totalPlan  = 0;

  let farmproxyinst;
  let farminst;
  let h2o;//stake token
  let melt;
  let usx;
  let usdc;
  let teamReward;
  let mulSiginst;
  let oracleinst;

  let startTime;

  before("init", async()=>{

  oracleinst = await Oracle.new();
  await oracleinst.setOperator(3,accounts[0]);

   //setup multisig
  let addresses = [accounts[7],accounts[8],accounts[9]];
  mulSiginst = await MultiSignature.new(addresses,2,{from : accounts[0]});
  console.log(mulSiginst.address);
//////////////////////LP POOL SETTING///////////////////////////////////////////////////
  h2o = await H2oToken.new("h2o",18);
  await h2o.mint(staker1,VAL_1M);
  await h2o.mint(staker2,VAL_1M);

/////////////////////////////reward token///////////////////////////////////////////
  melt = await RewardMeltToken.new("melt token","melt",18,mulSiginst.address);

//set phxfarm///////////////////////////////////////////////////////////
  farminst = await MinePool.new(mulSiginst.address,h2o.address,[h2o.address,melt.address]);
  console.log("pool address:", farminst.address);

  farmproxyinst = farminst;
    //set operator 0
  await farmproxyinst.setOperator(0,operator0);
  await farmproxyinst.setOperator(1,operator1);


  let block = await web3.eth.getBlock("latest");
  startTime = block.timestamp + 1000;
  console.log("set block time",startTime);

  let endTime = startTime + 3600*24*365;

  //h2o one secod 1 h2o
  let res = await farminst.setMineRate(0, web3.utils.toWei(""+day),day);
  assert.equal(res.receipt.status,true);

  res = await farminst.setPeriodFinish(0,startTime,endTime);
  assert.equal(res.receipt.status,true);

  res = await farminst.setMineRate(1, web3.utils.toWei(""+2*day),day);
  assert.equal(res.receipt.status,true);

  res = await farminst.setPeriodFinish(1,startTime,endTime);
  assert.equal(res.receipt.status,true);

////////////////////////set farmsc as admin to enable mint melt///////////////
  console.log("set farmsc as admin to enable mint melt");

  let msgData = melt.contract.methods.addAdmin(accounts[1]).encodeABI();
  let hash = await utils.createApplication(mulSiginst,accounts[9],melt.address,0,msgData);

  let index = await mulSiginst.getApplicationCount(hash);
  index = index.toNumber()-1;
  console.log(index);

  res = await mulSiginst.signApplication(hash,index,{from:accounts[7]});
  assert.equal(res.receipt.status,true);

  res = await mulSiginst.signApplication(hash,index,{from:accounts[8]})
  assert.equal(res.receipt.status,true);

  res = await utils.testSigViolation("multiSig addAdmin: This tx is aprroved",async function(){
          await melt.addAdmin(accounts[1],{from:accounts[9]});
    });
  assert.equal(res,true,"should return true");

  ////////////////////////////////////////////////////////////////////////////////////////////
  res = await melt.mint(farmproxyinst.address,VAL_10M,{from:accounts[1]});
  assert.equal(res.receipt.status,true);

  res = await h2o.mint(farmproxyinst.address,VAL_10M);
  assert.equal(res.receipt.status,true);
  })

  it("[0010] stake in,should pass", async()=>{
    ////////////////////////staker1///////////////////////////////////////////////////////////
    res = await h2o.approve(farmproxyinst.address,VAL_1M,{from:staker1});
    assert.equal(res.receipt.status,true);
    time.increaseTo(startTime+1);

    res = await farmproxyinst.deposit(VAL_1M,{from:staker1});
    assert.equal(res.receipt.status,true);

    let mineInfo = await farmproxyinst.getMineInfo(0);
    console.log("reward info 1",mineInfo[0].toString(10),mineInfo[1].toString(10));

    mineInfo = await farmproxyinst.getMineInfo(1);
    console.log("reward info 2",mineInfo[0].toString(10),mineInfo[1].toString(10));

/////////////////////////////////////////////////////////////////////////////////
    time.increaseTo(startTime+1000);
    await h2o.approve(farmproxyinst.address,VAL_1M,{from:staker2});
    res = await farmproxyinst.deposit(VAL_1M,{from:staker2});
    assert.equal(res.receipt.status,true);

    mineInfo = await farmproxyinst.getMineInfo(0);
    console.log(mineInfo[0].toString(10),mineInfo[1].toString(10));

  })


  it("[0020] check staker1 mined balance,should pass", async()=>{

     time.increase(2000);//2000 sec
     let res = await farmproxyinst.totalStaked();
     console.log("totalstaked=" + res);

    let block = await web3.eth.getBlock("latest");
     console.log("blocknum1=" + block.number)

    res = await farmproxyinst.allPendingReward(0,staker1)
    console.log("staker1 h2o pending reward",res.toString());


     res = await farmproxyinst.allPendingReward(1,staker1)
     console.log("staker1 melt pending reward",res.toString());


     let h2opreBalance = web3.utils.fromWei(await h2o.balanceOf(staker1));
     let meltpreBalance = web3.utils.fromWei(await melt.balanceOf(staker1));

     res = await farmproxyinst.withdraw(0,{from:staker1});
     assert.equal(res.receipt.status,true);

     let meltafterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
     console.log("staker1 h2o reward=" + (meltafterBalance - meltpreBalance));

      let h2oafterBalance = web3.utils.fromWei(await h2o.balanceOf(staker1))
      console.log("staker1 melt reward=" + (h2oafterBalance - h2opreBalance));

  })

})