const { time, expectEvent} = require("@openzeppelin/test-helpers");

//const TokenRelease = artifacts.require('tokenRelease');

const LpToken = artifacts.require('LpToken');

const WethToken = artifacts.require('LpToken');
const H2oToken = artifacts.require('LpToken');
//const Smelt = artifacts.require('smeltToken');

const Oracle = artifacts.require('Oracle');

//const TeamDistribute = artifacts.require('TeamDistribute');

//const MeltToken = artifacts.require("LpToken");
const MultiSignature = artifacts.require("multiSignature");

const JoeFarmChefV3 = artifacts.require("MasterChefJoeV3");
const JoeFarmChefV2 = artifacts.require("MasterChefJoeV2");
const JoeToken = artifacts.require('MockToken');
const USDCeToken = artifacts.require('BridgeToken');
const DefrostFarm = artifacts.require("FarmUsdcWithJoeV3");

const assert = require('chai').assert;
const Web3 = require('web3');

const BN = require("bn.js");
var utils = require('../utils.js');
web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

const UsdcDecimal = new BN(1000000);

/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/
contract('Boost farm Test', function (accounts){
    let rewardOneDay = new BN(300).mul(new BN(UsdcDecimal)).toString(10);//web3.utils.toWei('5000', 'ether');
    let blockSpeed = 2;
    let bocksPerDay = 3600*24/blockSpeed;
    let rewardPerBlock = new BN(rewardOneDay).div(new BN(bocksPerDay));
    rewardPerBlock = rewardPerBlock.toString(10);
    console.log(rewardPerBlock.toString(10));

    let staker1 = accounts[2];
    let staker2 = accounts[3];
    let staker3 = accounts[6];

    let teamMember1 = accounts[4];
    let teamMember2 = accounts[5];
    let teamMember3 = accounts[6];

    let teammems = [teamMember1,teamMember2];
    let teammemsRatio = [20,80];


    let VAL_10M = web3.utils.toWei('10000000', 'ether');
    let VAL_99M = web3.utils.toWei(  '99999999', 'ether');
    let VAL_100M = web3.utils.toWei('100000000', 'ether');
    let VAL_1B = web3.utils.toWei(  '1000000000', 'ether');
    let VAL_10B = web3.utils.toWei('10000000000', 'ether');

    let BOOST_499 = web3.utils.toWei('499', 'ether');
    let BOOST_1000 = web3.utils.toWei('1000', 'ether');
    let BOOST_3001 = web3.utils.toWei('3001', 'ether');
    let BOOST_9999 = web3.utils.toWei('9999', 'ether');
    let BOOST_100001 = web3.utils.toWei('100001', 'ether');

    let minutes = 60;
    let hour    = 60*60;
    let day     = 24*hour;
    let totalPlan  = 0;

    let farmproxyinst;
    let farminst;
    let lp;//stake token

    let usx;
    let usdc;
    let teamReward;
    let mulSiginst;
    let oracleinst;
    let startTime;
    let tokenFarmInt;
    let smelt;

    let tokenReleaseInt;

    let joeToken;
    let joeFarmChefV3Inst;
    let joeFarmChefV2Inst;

    async function initDoubleFarm(){

        joeToken = await JoeToken.new("Joe token","joe",18);
        dummyToken = await JoeToken.new("dummy token","joe",18);

        dummyToken.mint(accounts[0],web3.utils.toWei("10000",'ether'));
        joeFarmChefV2Inst = await JoeFarmChefV2.new(joeToken.address,accounts[7],accounts[8],accounts[9],web3.utils.toWei("1",'ether'),startTime,0,0,0);
        let res = await joeFarmChefV2Inst.add(100,dummyToken.address,"0x0000000000000000000000000000000000000000");


        joeFarmChefV3Inst = await JoeFarmChefV3.new(joeFarmChefV2Inst.address,joeToken.address,0);
        await dummyToken.approve(joeFarmChefV3Inst.address,web3.utils.toWei("100000",'ether'),{from: accounts[0]});
        await joeFarmChefV3Inst.init(dummyToken.address);

        res = await joeFarmChefV3Inst.add(100,lp.address,"0x0000000000000000000000000000000000000000");
        assert.equal(res.receipt.status,true);
    }


    async function enableDoubleFarm(){
        {
            let msgData = farmproxyinst.contract.methods.setDoubleFarming(0,joeFarmChefV3Inst.address,0).encodeABI();

            let hash = await utils.createApplication(mulSiginst, accounts[8], farmproxyinst.address, 0, msgData);

            let index = await mulSiginst.getApplicationCount(hash);
            index = index.toNumber() - 1;
            console.log(index);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[7]});
            assert.equal(res.receipt.status, true);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[8]})
            assert.equal(res.receipt.status, true);

            res = await utils.testSigViolation("multiSig setMultiUsersInfo: This tx is aprroved", async function () {
                await farmproxyinst.setDoubleFarming(0,joeFarmChefV3Inst.address,0,{from:accounts[8]});
            });

            assert.equal(res, true);
        }

        {
            let msgData = farmproxyinst.contract.methods.enableDoubleFarming(0,true).encodeABI();

            let hash = await utils.createApplication(mulSiginst, accounts[8], farmproxyinst.address, 0, msgData);

            let index = await mulSiginst.getApplicationCount(hash);
            index = index.toNumber() - 1;
            console.log(index);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[7]});
            assert.equal(res.receipt.status, true);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[8]})
            assert.equal(res.receipt.status, true);

            res = await utils.testSigViolation("multiSig setMultiUsersInfo: This tx is aprroved", async function () {
                await farmproxyinst.enableDoubleFarming(0,true,{from:accounts[8]});
            });

            assert.equal(res, true);
        }

        console.log("setting end")

    }


    before("init", async()=>{
        oracleinst = await Oracle.new();
        await oracleinst.setOperator(3,accounts[0]);

        //setup multisig
        let addresses = [accounts[7],accounts[8],accounts[9]];
        mulSiginst = await MultiSignature.new(addresses,2,{from : accounts[0]});
        console.log(mulSiginst.address);

//////////////////////LP POOL SETTING///////////////////////////////////////////////////
        lp = await LpToken.new("lptoken",18);

        await lp.mint(staker1,VAL_1B);
        await lp.mint(staker2,VAL_1B);
        await lp.mint(staker3,VAL_1B);

        usx = await LpToken.new("usx",18);
        await usx.mint(lp.address,VAL_1B);

        usdc = await WethToken.new("usdc",6);

        await lp.setReserve(usx.address,usdc.address);
//set farm///////////////////////////////////////////////////////////
        farmproxyinst = await DefrostFarm.new(mulSiginst.address, accounts[8], accounts[9],usdc.address);
        console.log("pool address:", farmproxyinst.address);

        let block = await web3.eth.getBlock("latest");
        startTime = block.timestamp + 1000;
        console.log("set block time", startTime);

        let endBlock = block.number + bocksPerDay * 365;

{
    let msgData = farmproxyinst.contract.methods.add(lp.address,
                                                     startTime,
                                                     endBlock,
                                                     rewardPerBlock,
                                                     rewardOneDay,
                                                     24 * 3600,
                                                     5).encodeABI();

    let hash = await utils.createApplication(mulSiginst, accounts[8], farmproxyinst.address, 0, msgData);

    let index = await mulSiginst.getApplicationCount(hash);
    index = index.toNumber() - 1;
    console.log(index);

    res = await mulSiginst.signApplication(hash, index, {from: accounts[7]});
    assert.equal(res.receipt.status, true);

    res = await mulSiginst.signApplication(hash, index, {from: accounts[8]})
    assert.equal(res.receipt.status, true);

    res = await utils.testSigViolation("multiSig setMultiUsersInfo: This tx is aprroved", async function () {
         await farmproxyinst.add(lp.address,
            startTime,
            endBlock,
            rewardPerBlock,
            rewardOneDay,
            24 * 3600,
            5,
            {from:accounts[8]});
    });

    assert.equal(res, true);
}

////////////////////////set farmsc as admin to enable mint melt///////////////
    await usdc.mint(farmproxyinst.address,new BN(100000000000).toString(10));

//////////////////////test setting/////////////////////////////////////////////////////
        res = await oracleinst.setPrice(usdc.address,100000000);//usdc one dollar
        console.log("normall setting end");

        await initDoubleFarm();

        await enableDoubleFarm();

    })


    it("[0010] stake in,should pass", async()=>{
        ////////////////////////staker1///////////////////////////////////////////////////////////
        res = await lp.approve(farmproxyinst.address,VAL_1B,{from:staker1});
        assert.equal(res.receipt.status,true);

        res = await lp.approve(farmproxyinst.address,VAL_1B,{from:staker2});
        assert.equal(res.receipt.status,true);

        res = await lp.approve(farmproxyinst.address,VAL_1B,{from:staker3});
        assert.equal(res.receipt.status,true);


        time.increaseTo(startTime+100);

        let preBal = await lp.balanceOf(farmproxyinst.address);
        console.log("prebalance=",preBal.toString(10));
        res = await farmproxyinst.deposit(0,VAL_100M,{from:staker1});
        assert.equal(res.receipt.status,true);

        utils.sleep(1000);
        res = await farmproxyinst.deposit(0,VAL_100M,{from:staker2});
        assert.equal(res.receipt.status,true);

        utils.sleep(1000);
        res = await farmproxyinst.deposit(0,VAL_100M,{from:staker3});
        assert.equal(res.receipt.status,true);

        let afterBal = await lp.balanceOf(farmproxyinst.address);
        console.log("afterbalance=",afterBal.toString(10));


        let mineInfo = await farmproxyinst.getMineInfo(0);
        console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
            mineInfo[2].toString(10),mineInfo[3].toString(10));
/////////////////////////////////////////////////////////////////////////////////

        mineInfo = await farmproxyinst.getMineInfo(0);
        console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
            mineInfo[2].toString(10),mineInfo[3].toString(10));

        let block = await web3.eth.getBlock(mineInfo[2]);
        console.log("start block time",block.timestamp);

    })

    it("[0030] check staker reward,should pass", async()=> {
        utils.sleep(3000);
        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0, staker1)
        console.log("allpending=", web3.utils.fromWei(res[0]), new BN(res[1]).toString(10), web3.utils.fromWei(res[2]));

        res = await farmproxyinst.allPendingReward(0, staker2)
        console.log("allpending=", web3.utils.fromWei(res[0]), new BN(res[1]).toString(10), web3.utils.fromWei(res[2]));

        res = await farmproxyinst.allPendingReward(0, staker3)
        console.log("allpending=", web3.utils.fromWei(res[0]), new BN(res[1]).toString(10), web3.utils.fromWei(res[2]));

    })

    it("[0040] check staker1 withdraw reward,should pass", async()=> {
        let usdcPreBalance = await usdc.balanceOf(staker1);
        let joePreBalance = web3.utils.fromWei(await joeToken.balanceOf(staker1));

        res = await farmproxyinst.withdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);

        let usdcAfterBalance = await usdc.balanceOf(staker1);
        console.log("staker1 usdc reward=" + (usdcAfterBalance - usdcPreBalance));

        let joeAfterBalance = web3.utils.fromWei(await joeToken.balanceOf(staker1));
        console.log("staker1 joe reward=" + (joeAfterBalance - joePreBalance));
    })

    it("[0050] check staker1 withdraw lp,should pass", async()=>{
        time.increase(2000);

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("allpending=",res[0].toString(),res[1].toString(),res[2].toString());
        let stakeAmount = res[0];

        let preBalance = await usdc.balanceOf(staker1);
        let pngpreBalance = web3.utils.fromWei(await joeToken.balanceOf(staker1));

        let lpprebalance = web3.utils.fromWei(await lp.balanceOf(staker1));

        res = await farmproxyinst.withdraw(0,stakeAmount,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = await usdc.balanceOf(staker1);
        console.log("staker1 usdc reward=" + (afterBalance - preBalance));

        let pngpafterBalance = web3.utils.fromWei(await joeToken.balanceOf(staker1));
        console.log("joe reward=" + (pngpafterBalance - pngpreBalance));

        let lpafterbalance = web3.utils.fromWei(await lp.balanceOf(staker1));
        console.log("lp get back=" + (lpafterbalance - lpprebalance));

    })

})
