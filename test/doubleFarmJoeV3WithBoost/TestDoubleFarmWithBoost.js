const { time, expectEvent} = require("@openzeppelin/test-helpers");

const TokenRelease = artifacts.require('tokenRelease');

const LpToken = artifacts.require('LpToken');

const WethToken = artifacts.require('LpToken');
const H2oToken = artifacts.require('LpToken');
const Smelt = artifacts.require('smeltToken');

const Oracle = artifacts.require('Oracle');

const TeamDistribute = artifacts.require('TeamDistribute');

const MeltToken = artifacts.require("LpToken");
const MultiSignature = artifacts.require("multiSignature");

const JoeFarmChefV3 = artifacts.require("MasterChefJoeV3");
const JoeFarmChefV2 = artifacts.require("MasterChefJoeV2");
const JoeToken = artifacts.require('MockToken');

const DefrostFarm = artifacts.require("DefrostBoostFarmV3");
const BoostTokenFarm = artifacts.require("BoostTokenFarmV3");

const assert = require('chai').assert;
const Web3 = require('web3');

const BN = require("bn.js");
var utils = require('../utils.js');
web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));


/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/
contract('Boost farm Test', function (accounts){
    let rewardOneDay = web3.utils.toWei('5000', 'ether');
    let blockSpeed = 5;
    let bocksPerDay = 3600*24/blockSpeed;
    let rewardPerBlock = new BN(rewardOneDay).div(new BN(bocksPerDay));
    console.log(rewardPerBlock.toString(10));

    let staker1 = accounts[2];
    let staker2 = accounts[3];
    let staker3 = accounts[6];

    let teamMember1 = accounts[4];
    let teamMember2 = accounts[5];
    let teamMember3 = accounts[6];

    let teammems = [teamMember1,teamMember2];
    let teammemsRatio = [20,80];

    let disSpeed1 = web3.utils.toWei('1', 'ether');

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
    let melt;
    let h2o;

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

        usdc = await WethToken.new("lptoken",18);
        await usdc.mint(lp.address,VAL_1B);

        await lp.setReserve(usx.address,usdc.address);
/////////////////////////////reward token///////////////////////////////////////////
        h2o = await H2oToken.new("h2o",18);
        await h2o.mint(accounts[0],VAL_1B);

        melt = await MeltToken.new("melt",18);
        await melt.mint(accounts[0],VAL_1B);

        smelt = await Smelt.new("melt token","melt",18,accounts[0]);

        await smelt.mint(staker1,VAL_1B);
        await smelt.mint(staker2,VAL_1B);
        await smelt.mint(staker3,VAL_1B);
/////////////////////////////////init token release//////////////////////////////////////////////////////
        tokenReleaseInt = await TokenRelease.new(mulSiginst.address,accounts[8],accounts[9]);
        let owner = await tokenReleaseInt.owner();


        res = await tokenReleaseInt.setParameter(melt.address,day,6,200,day,{from:accounts[0]});
        assert.equal(res.receipt.status,true);

        console.log("owner check",owner,accounts[0]);

//set farm///////////////////////////////////////////////////////////

        farmproxyinst = await DefrostFarm.new(mulSiginst.address, accounts[8], accounts[9]);
        console.log("pool address:", farmproxyinst.address);

        let block = await web3.eth.getBlock("latest");
        startTime = block.timestamp + 1000;
        console.log("set block time", startTime);

        let endBlock = block.number + bocksPerDay * 365;

{
    let msgData = farmproxyinst.contract.methods.add(lp.address,
                                                     startTime,
                                                     endBlock,
                                                     disSpeed1,
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
            disSpeed1,
            rewardOneDay,
            24 * 3600,
            5,
            {from:accounts[8]});
    });

    assert.equal(res, true);
}

/////////////////////////////////team reward sc set////////////////////////////
        console.log("team reward sc set");
        teamReward = await TeamDistribute.new(mulSiginst.address,accounts[8],accounts[9],melt.address);

        res = await teamReward.setMultiUsersInfo(teammems,teammemsRatio);
        assert.equal(res.receipt.status,true);

///////////////////////////////////////////////////////////////////////////////
        console.log("token farm sc create");
        tokenFarmInt = await BoostTokenFarm.new(mulSiginst.address,accounts[8],accounts[9],farmproxyinst.address,h2o.address);

{
    let duration = 3600*24;
    let rewardDay = web3.utils.toWei(""+0,'ether');

    let msgData = tokenFarmInt.contract.methods.setMineRate(rewardDay,duration).encodeABI();
    let hash = await utils.createApplication(mulSiginst, accounts[8], tokenFarmInt.address, 0, msgData);

    let index = await mulSiginst.getApplicationCount(hash);
    index = index.toNumber() - 1;
    console.log(index);

    res = await mulSiginst.signApplication(hash, index, {from: accounts[7]});
    assert.equal(res.receipt.status, true);

    res = await mulSiginst.signApplication(hash, index, {from: accounts[8]})
    assert.equal(res.receipt.status, true);

    res = await utils.testSigViolation("multiSig setMultiUsersInfo: This tx is aprroved", async function () {
            await  tokenFarmInt.setMineRate(rewardDay,duration,{from:accounts[8]});
    });

    assert.equal(res, true, "should return true");

}

{

    let endTime = startTime + 3600*24*365*10;

    let msgData = tokenFarmInt.contract.methods.setPeriodFinish(startTime,endTime).encodeABI();
    let hash = await utils.createApplication(mulSiginst, accounts[8], tokenFarmInt.address, 0, msgData);

    let index = await mulSiginst.getApplicationCount(hash);
    index = index.toNumber() - 1;
    console.log(index);

    res = await mulSiginst.signApplication(hash, index, {from: accounts[7]});
    assert.equal(res.receipt.status, true);

    res = await mulSiginst.signApplication(hash, index, {from: accounts[8]})
    assert.equal(res.receipt.status, true);

    res = await utils.testSigViolation("multiSig setMultiUsersInfo: This tx is aprroved", async function () {
        await  tokenFarmInt.setPeriodFinish(startTime,endTime,{from:accounts[8]});
    });

    assert.equal(res, true, "should return true");

}
////////////////////////set farmsc as admin to enable mint melt///////////////

   res = await melt.transfer(farmproxyinst.address,VAL_10M,{from:accounts[0]});
   res = await h2o.transfer(farmproxyinst.address,VAL_1B,{from:accounts[0]});

///////////////////////////////////////////////////////////////////////////////
   {
            let msgData = farmproxyinst.contract.methods.setDefrostAddress( melt.address,
                                                                            h2o.address,
                                                                            teamReward.address,
                                                                            tokenReleaseInt.address,
                                                                            tokenFarmInt.address,
                                                                            smelt.address).encodeABI();

            let hash = await utils.createApplication(mulSiginst, accounts[8], farmproxyinst.address, 0, msgData);

            let index = await mulSiginst.getApplicationCount(hash);
            index = index.toNumber() - 1;
            console.log(index);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[7]});
            assert.equal(res.receipt.status, true);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[8]})
            assert.equal(res.receipt.status, true);

            res = await utils.testSigViolation("multiSig setMultiUsersInfo: This tx is aprroved", async function () {
                await farmproxyinst.setDefrostAddress(  melt.address,
                                                        h2o.address,
                                                        teamReward.address,
                                                        tokenReleaseInt.address,
                                                        tokenFarmInt.address,
                                                        smelt.address,
                                                        {from: accounts[8]});
            });

            assert.equal(res, true, "should return true");

        }

///////////////////////test setting/////////////////////////////////////////////////////
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

        res = await smelt.approve(farmproxyinst.address,VAL_1B,{from:staker1});
        assert.equal(res.receipt.status,true);

        res = await smelt.approve(farmproxyinst.address,VAL_1B,{from:staker2});
        assert.equal(res.receipt.status,true);

        res = await smelt.approve(farmproxyinst.address,VAL_1B,{from:staker3});
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

   it("[0020] check staker1 mined balance,should pass", async()=>{
            console.log("====================================================================================")
            time.increase(3600*24);
            let res = await farmproxyinst.totalStaked(0);
            console.log("totalstaked=" + res);

            let block = await web3.eth.getBlock("latest");
            console.log("blocknum1=" + block.number)

            res = await farmproxyinst.allPendingReward(0,staker1)
            console.log("staker1 allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

            res = await farmproxyinst.allPendingReward(0,staker2)
            console.log("staker2 allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

            res = await farmproxyinst.allPendingReward(0,staker3)
            console.log("staker3 allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

            res = await farmproxyinst.getPoolInfo(0)
            console.log("poolinf=",res[0].toString(),res[1].toString(),res[2].toString(),
                res[3].toString(),res[4].toString(),res[5].toString(),
                res[6].toString(),res[7].toString(),res[8].toString());

            res = await farmproxyinst.getMineInfo(0);
            console.log(res[0].toString(),
                res[1].toString(),
                res[2].toString(),
                res[3].toString());

            let preTeamBalance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
            let preTeamBalance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));

            let preBalance = web3.utils.fromWei(await melt.balanceOf(staker1));
            let pngpreBalance = web3.utils.fromWei(await h2o.balanceOf(staker1));
            let preBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2));
            let preBalance3 = web3.utils.fromWei(await melt.balanceOf(staker3));


            res = await farmproxyinst.withdraw(0,0,{from:staker1});
            assert.equal(res.receipt.status,true);

            res = await farmproxyinst.withdraw(0,0,{from:staker2});
            assert.equal(res.receipt.status,true);

            res = await farmproxyinst.withdraw(0,0,{from:staker3});
            assert.equal(res.receipt.status,true);

            let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
            console.log("staker1 melt reward=" + (afterBalance - preBalance));

            let afterBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2))
            console.log("staker2 melt reward=" + (afterBalance2 - preBalance2));

            let afterBalance3 = web3.utils.fromWei(await melt.balanceOf(staker3))
            console.log("staker3 melt reward=" + (afterBalance3 - preBalance3));

            let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
            let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
            console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
            console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

            let pngpafterBalance = web3.utils.fromWei(await h2o.balanceOf(staker1));
            console.log("png reward=" + (pngpafterBalance - pngpreBalance));
            console.log("====================================================================================")

            utils.sleep(2000);
            time.increase(3600);

    })


    it("[0030] stake in boost smelt,should pass", async()=>{
        console.log("=======================begin boost===========================")
        let staker1BoostFactor = await farmproxyinst.getUserBoostFactor(BOOST_499);
        console.log("staker 1 boost factor",staker1BoostFactor.toString(10));

        let staker2BoostFactor = await farmproxyinst.getUserBoostFactor(BOOST_3001);
        console.log("staker 2 boost factor",staker2BoostFactor.toString(10));

        let staker3BoostFactor = await farmproxyinst.getUserBoostFactor(BOOST_100001);
        console.log("staker 3 boost factor",staker3BoostFactor.toString(10));

        let getBoostMineInfo = await farmproxyinst.getBoostMineInfo();
        console.log("boost mine info",getBoostMineInfo[0].toString(10),getBoostMineInfo[1].toString(10));

//////////////////////////////////////////////////////////////////////////////////
        let preBal = await smelt.balanceOf(farmproxyinst.address);
        console.log("smelt prebalance=",preBal.toString(10));
        res = await farmproxyinst.boostDeposit(0,BOOST_499,{from:staker1});
        assert.equal(res.receipt.status,true);
        //utils.sleep(1000);


        res = await farmproxyinst.boostDeposit(0,BOOST_3001,{from:staker2});
        assert.equal(res.receipt.status,true);

        //utils.sleep(1000);
        res = await farmproxyinst.boostDeposit(0,VAL_10M,{from:staker3});
        assert.equal(res.receipt.status,true);

        let afterBal = await smelt.balanceOf(farmproxyinst.address);
        console.log("smelt afterbalance=",afterBal.toString(10));

/////////////////////////////////////////////////////////////////////////////////////////
        //time.increase(3600*24);
        utils.sleep(10000);
        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        let boostBal = await farmproxyinst.balanceOf(staker1);
        console.log("staker1 boost balance",web3.utils.fromWei(boostBal));

        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        let getBoostPendingReward = await farmproxyinst.boostPendingReward(staker1);
        console.log("boost staker1 reward",web3.utils.fromWei(getBoostPendingReward));
        console.log("-----------------------------------------------------------------");
        rewardInfo = await farmproxyinst.getRewardInfo(0,staker2);
        boostBal = await farmproxyinst.balanceOf(staker2);
        console.log("staker2 boost balance",web3.utils.fromWei(boostBal));
        console.log("staker2 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker2 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker2 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker2 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker2 extern reward",web3.utils.fromWei(rewardInfo[4]));
        getBoostPendingReward = await farmproxyinst.boostPendingReward(staker2);
        console.log("boost staker2 reward",web3.utils.fromWei(getBoostPendingReward));
        console.log("-----------------------------------------------------------------");
        rewardInfo = await farmproxyinst.getRewardInfo(0,staker3);
        boostBal = await farmproxyinst.balanceOf(staker3);
        console.log("staker3 boost balance",web3.utils.fromWei(boostBal));
        console.log("staker3 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker3 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker3 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker3 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker3 extern reward",web3.utils.fromWei(rewardInfo[4]));
        getBoostPendingReward = await farmproxyinst.boostPendingReward(staker3);
        console.log("boost staker3 reward",web3.utils.fromWei(getBoostPendingReward));

    })


    it("[0040] check staker1 withdraw reward,should pass", async()=>{
/////////////////////////////////////////////////////////////////////////////////
        {
            console.log("set reward rate");
            let duration = 3600*24;
            let rewardDay = web3.utils.toWei(""+3600,'ether');

            let msgData = tokenFarmInt.contract.methods.setMineRate(rewardDay,duration).encodeABI();
            let hash = await utils.createApplication(mulSiginst, accounts[8], tokenFarmInt.address, 0, msgData);

            let index = await mulSiginst.getApplicationCount(hash);
            index = index.toNumber() - 1;
            console.log(index);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[7]});
            assert.equal(res.receipt.status, true);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[8]})
            assert.equal(res.receipt.status, true);

            res = await utils.testSigViolation("multiSig setMultiUsersInfo: This tx is aprroved", async function () {
                await  tokenFarmInt.setMineRate(rewardDay,duration,{from:accounts[8]});
            });

            assert.equal(res, true, "should return true");
            utils.sleep(2000);
            time.increase(3600*24);

            let getBoostPendingReward = await farmproxyinst.boostPendingReward(staker1);
            console.log("boost staker1 reward",web3.utils.fromWei(getBoostPendingReward));

            getBoostPendingReward = await farmproxyinst.boostPendingReward(staker2);
            console.log("boost staker1 reward",web3.utils.fromWei(getBoostPendingReward));
        }
        {//deposit again after boost start

            utils.sleep(1000);
            let preBalance = web3.utils.fromWei(await h2o.balanceOf(staker1));
            res = await farmproxyinst.deposit(0, VAL_10M, {from: staker1});
            assert.equal(res.receipt.status, true);
            let afterBalance = web3.utils.fromWei(await h2o.balanceOf(staker1));
            console.log("staker1 deposit h2o reward=" + (afterBalance - preBalance));


            utils.sleep(1000);
            lpreBalance = web3.utils.fromWei(await h2o.balanceOf(staker2));
            res = await farmproxyinst.deposit(0, VAL_10M, {from: staker2});
            assert.equal(res.receipt.status, true);
            afterBalance = web3.utils.fromWei(await h2o.balanceOf(staker2));
            console.log("staker2 deposit h2o reward=" + (afterBalance - preBalance));

            utils.sleep(1000);
            lpreBalance = web3.utils.fromWei(await h2o.balanceOf(staker3));
            res = await farmproxyinst.deposit(0, VAL_10M, {from: staker3});
            assert.equal(res.receipt.status, true);
            afterBalance = web3.utils.fromWei(await h2o.balanceOf(staker3));
            console.log("staker2 deposit h2o reward=" + (afterBalance - preBalance));
        }

/////////////////////////////////////////////////////////////////////////////////
        time.increase(3600*24);
        let preBalance = web3.utils.fromWei(await h2o.balanceOf(staker1));

        res = await farmproxyinst.boostwithdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await h2o.balanceOf(staker1));

        console.log("staker1 h2o reward=" + (afterBalance - preBalance));
//////////////////////////////////////////////////////////////////////////////
        preBalance = web3.utils.fromWei(await h2o.balanceOf(staker2));

        res = await farmproxyinst.boostwithdraw(0,0,{from:staker2});
        assert.equal(res.receipt.status,true);

        afterBalance = web3.utils.fromWei(await h2o.balanceOf(staker2))
        console.log("staker2 h2o reward=" + (afterBalance - preBalance));

/////////////////////////////////////////////////////////////////////////////////////////
        preBalance = web3.utils.fromWei(await h2o.balanceOf(staker3));

        res = await farmproxyinst.boostwithdraw(0,0,{from:staker3});
        assert.equal(res.receipt.status,true);

        afterBalance = web3.utils.fromWei(await h2o.balanceOf(staker3));
        console.log("staker1 h2o reward=" + (afterBalance - preBalance));


    })

    it("[0050] check stakers withdraw boost stake,should pass", async()=>{
        utils.sleep(2000);
        let preBalance = web3.utils.fromWei(await smelt.balanceOf(staker1));
        let stakedBal = await farmproxyinst.boostStakedFor(staker1);
        res = await farmproxyinst.boostwithdraw(0,stakedBal,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await smelt.balanceOf(staker1));

        console.log("staker1 smelt getback=" + (afterBalance - preBalance));
//////////////////////////////////////////////////////////////////////////////
        preBalance = web3.utils.fromWei(await smelt.balanceOf(staker2));
        stakedBal = await farmproxyinst.boostStakedFor(staker2);
        res = await farmproxyinst.boostwithdraw(0,stakedBal,{from:staker2});
        assert.equal(res.receipt.status,true);

        afterBalance = web3.utils.fromWei(await smelt.balanceOf(staker2));

        console.log("staker1 smelt getback=" + (afterBalance - preBalance));

/////////////////////////////////////////////////////////////////////////////////////////
        preBalance = web3.utils.fromWei(await smelt.balanceOf(staker3));
        stakedBal = await farmproxyinst.boostStakedFor(staker3);
        res = await farmproxyinst.boostwithdraw(0,stakedBal,{from:staker3});
        assert.equal(res.receipt.status,true);

        afterBalance = web3.utils.fromWei(await smelt.balanceOf(staker3));

        console.log("staker1 smelt getback=" + (afterBalance - preBalance));

    })

    it("[0050] check stakers withdraw boost stake,should pass", async()=>{
        let preBalance = web3.utils.fromWei(await h2o.balanceOf(staker1));

        {
            console.log("set reward rate");
            let duration = 3600*24;
            let rewardDay = web3.utils.toWei(""+3600,'ether');

            let msgData = tokenFarmInt.contract.methods.getbackLeftMiningToken(staker1).encodeABI();
            let hash = await utils.createApplication(mulSiginst, accounts[8], tokenFarmInt.address, 0, msgData);

            let index = await mulSiginst.getApplicationCount(hash);
            index = index.toNumber() - 1;
            console.log(index);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[7]});
            assert.equal(res.receipt.status, true);

            res = await mulSiginst.signApplication(hash, index, {from: accounts[8]})
            assert.equal(res.receipt.status, true);

            res = await utils.testSigViolation("multiSig setMultiUsersInfo: This tx is aprroved", async function () {
                await  tokenFarmInt.getbackLeftMiningToken(staker1,{from:accounts[8]});
            });

            assert.equal(res, true, "should return true");

        }

        let afterBalance = web3.utils.fromWei(await smelt.balanceOf(staker1));
        console.log("h2o reward getback=" + (afterBalance - preBalance));



    })


})
