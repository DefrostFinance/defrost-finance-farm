const { time, expectEvent} = require("@openzeppelin/test-helpers");
const MinePool = artifacts.require('defrostPangalinFarmFixedRatio');

const LpToken = artifacts.require('LpToken');
const WethToken = artifacts.require('LpToken');

const Oracle = artifacts.require('Oracle');
const TokenRelease = artifacts.require('tokenRelease');
const TeamDistribute = artifacts.require('TeamDistribute');

const MeltToken = artifacts.require("DefrostToken");
const MultiSignature = artifacts.require("multiSignature");

const PngManager = artifacts.require("LiquidityPoolManager");
const StakingRewards = artifacts.require("StakingRewards");
const PngToken = artifacts.require('MockToken');
const AvaxToken = artifacts.require('MockToken');

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

    let staker1 = accounts[2];
    let staker2 = accounts[3];
    let staker3 = accounts[6];

    let teamMember1 = accounts[4];
    let teamMember2 = accounts[5];
    let teammems = [teamMember1,teamMember2];
    let teammemsRatio = [20,80];

    let disSpeed1 = web3.utils.toWei('1', 'ether');

    let VAL_1M = web3.utils.toWei('1000000', 'ether');
    let VAL_10M = web3.utils.toWei('10000000', 'ether');
    let VAL_99M = web3.utils.toWei(  '99999999', 'ether');
    let VAL_100M = web3.utils.toWei('100000000', 'ether');
    let VAL_1B = web3.utils.toWei('1000000000', 'ether');
    let VAL_10B = web3.utils.toWei('10000000000', 'ether');

    let WITHTELIST_MINIMUM = VAL_100M ;

    let minutes = 60;
    let hour    = 60*60;
    let day     = 24*hour;
    let totalPlan  = 0;

    let farmproxyinst;
    let farminst;
    let lp;//stake token
    let melt;
    let usx;
    let usdc;
    let teamReward;
    let mulSiginst;
    let oracleinst;
    let startTime;

    let pngManagerInst;
    let pngStakeRewardInt;
    let pngInst;
    let avaxInst;

    async function initPngDoubleFarm(){
        pngInst = await PngToken.new("png","png",18);
        AvaxInst = await AvaxToken.new("avax","avax",18);

        pngManagerInst = await PngManager.new(AvaxInst.address,pngInst.address);
        let res = await pngManagerInst.addWhitelistedPool(lp.address);
        assert.equal(res.receipt.status,true);

        let pngStakeRewardAddress = await pngManagerInst.stakes(lp.address);
        pngStakeRewardInt = await StakingRewards.at(pngStakeRewardAddress);

        res = await pngStakeRewardInt.setRewardsDuration(365*day);

        assert.equal(res.receipt.status,true);

        res = await pngInst.mint(pngStakeRewardInt.address,new BN(rewardOneDay).mul(new BN(500)));
        assert.equal(res.receipt.status,true);

        res = await pngStakeRewardInt.notifyRewardAmount(new BN(rewardOneDay).mul(new BN(365)));
        assert.equal(res.receipt.status,true);

    }

    async function enablePngDoubleFarm(){

        let res = await farmproxyinst.setDoubleFarming(0,pngManagerInst.address,pngInst.address);
        assert.equal(res.receipt.status,true);

        res = await farmproxyinst.enableDoubleFarming(0,true);
        assert.equal(res.receipt.status,true);
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
        melt = await MeltToken.new("melt token","melt",18,accounts[0],accounts[1],accounts[2]);

/////////////////////////////////init token release//////////////////////////////////////////////////////
        tokenReleaseInt = await TokenRelease.new(mulSiginst.address,accounts[8],accounts[9]);
        let owner = await tokenReleaseInt.owner();
        console.log("owner check",owner,accounts[0]);

        res = await tokenReleaseInt.setParameter(melt.address,day,6,200,day,{from:accounts[0]});
        assert.equal(res.receipt.status,true);
//set farm///////////////////////////////////////////////////////////
        farminst = await MinePool.new(mulSiginst.address,accounts[8],accounts[9]);
        console.log("pool address:", farminst.address);

        farmproxyinst = farminst;
        //await PoolProxy.new(farminst.address,melt.address,mulSiginst.address);
        console.log("proxy address:",farmproxyinst.address);

        // farmproxyinst = await MinePool.at(farmproxyinst.address);
        // console.log("proxy address:" + farmproxyinst.address);

        let block = await web3.eth.getBlock("latest");
        startTime = block.timestamp + 1000;
        console.log("set block time",startTime);

        let endBlock = block.number + bocksPerDay*365;

        res = await farmproxyinst.add(lp.address,
            startTime,
            endBlock,
            disSpeed1,
            rewardOneDay,
            24*3600,
            5);
        assert.equal(res.receipt.status,true);

//  res = await farmproxyinst.setOperator(1,accounts[0]);
//  assert.equal(res.receipt.status,true);
/////////////////////////////////team reward sc set////////////////////////////
        console.log("team reward sc set");
        teamReward = await TeamDistribute.new(mulSiginst.address,accounts[8],accounts[9],melt.address);

        // let teamProxy = await TeamDistributeProxy.new(teamReward.address,melt.address,mulSiginst.address);
        // teamReward = await TeamDistribute.at(teamProxy.address);


        res = await teamReward.setMultiUsersInfo(teammems,teammemsRatio);
        assert.equal(res.receipt.status,true);

////////////////////////set farmsc as admin to enable mint melt///////////////

        res = await melt.transfer(farmproxyinst.address,VAL_10M,{from:accounts[0]});

///////////////////////////////////////////////////////////////////////////////
        //set reward,oracle,usx stable,teamreward
        res = await farmproxyinst.setDefrostAddress(melt.address,
            oracleinst.address,
            usx.address,
            teamReward.address,
            tokenReleaseInt.address);

        assert.equal(res.receipt.status,true);

        //set whitelist ratio
        res = await farmproxyinst.setFixedWhitelistPara(200,WITHTELIST_MINIMUM);
        assert.equal(res.receipt.status,true);

        //set whitelist
        res = await farmproxyinst.setWhiteList([staker1,staker2]);
        assert.equal(res.receipt.status,true);

        //set team ratio
        // res = await farmproxyinst.setTeamRewardRatio([0,VAL_1M,VAL_10M,VAL_1B,VAL_10B],[10,35,5,6,65],{from:operator1});
        // assert.equal(res.receipt.status,true);

        res = await farmproxyinst.setFixedTeamRatio(10);
/////////////////////////////////init//////////////////////////////////////////////////////
        console.log("init double farm");
        await initPngDoubleFarm();
        await enablePngDoubleFarm();

///////////////////////test setting/////////////////////////////////////////////////////
        res = await oracleinst.setPrice(usdc.address,100000000);//usdc one dollar

        console.log("normall setting end");
    })

    it("[0010] stake in,should pass", async()=>{
        ////////////////////////staker1///////////////////////////////////////////////////////////
        res = await lp.approve(farmproxyinst.address,VAL_1B,{from:staker1});
        assert.equal(res.receipt.status,true);

        res = await lp.approve(farmproxyinst.address,VAL_1B,{from:staker2});
        assert.equal(res.receipt.status,true);

        res = await lp.approve(farmproxyinst.address,VAL_1B,{from:staker3});
        assert.equal(res.receipt.status,true);

        // res = await lp.approve(joeStakeRewardInt.address,VAL_1M,{from:staker1});
        // assert.equal(res.receipt.status,true);

        time.increaseTo(startTime+100);

        let preBal = await pngInst.balanceOf(farmproxyinst.address);
        console.log("prebalance=",preBal.toString(10));
        res = await farmproxyinst.deposit(0,VAL_100M,{from:staker1});
        assert.equal(res.receipt.status,true);

        utils.sleep(1000);
        res = await farmproxyinst.deposit(0,VAL_100M,{from:staker2});
        assert.equal(res.receipt.status,true);

        utils.sleep(1000);
        res = await farmproxyinst.deposit(0,VAL_99M,{from:staker3});
        assert.equal(res.receipt.status,true);

        let afterBal = await pngInst.balanceOf(farmproxyinst.address);
        console.log("afterbalance=",afterBal.toString(10));

        let mineInfo = await farmproxyinst.getMineInfo(0);
        console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
            mineInfo[2].toString(10),mineInfo[3].toString(10));
/////////////////////////////////////////////////////////////////////////////////
//         time.increaseTo(startTime+1000);
//         await lp.approve(farmproxyinst.address,VAL_1B,{from:staker2});
//         res = await farmproxyinst.deposit(0,VAL_1M,{from:staker2});
//         assert.equal(res.receipt.status,true);
//
//         mineInfo = await farmproxyinst.getMineInfo(0);
//         console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
//             mineInfo[2].toString(10),mineInfo[3].toString(10));

        let block = await web3.eth.getBlock(mineInfo[2]);
        console.log("start block time",block.timestamp);

    })


    it("[0020] check staker1 mined balance,should pass", async()=>{
        console.log("====================================================================================")
        time.increase(200000);
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
        let pngpreBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        let preBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2));
        let preBalance3 = web3.utils.fromWei(await melt.balanceOf(staker3));
        //res = await farmproxyinst.getAllClaimableReward(0,staker1)
        //console.log("all claimable reward:", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.withdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);
        utils.sleep(1000);
        res = await farmproxyinst.withdraw(0,0,{from:staker2});
        assert.equal(res.receipt.status,true);
        utils.sleep(1000);
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

        let pngpafterBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));
        console.log("====================================================================================")

    })

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //return (depositAmount,claimable,locked,claimed,joeReward);
    it("[0021] check locked and pending balance,should pass", async()=>{
        time.increase(day+1);

        // let staker1Claimed = web3.utils.fromWei(await tokenReleaseInt.userFarmClaimedBalances(staker1));
        // console.log("staker1 claimed reward=",staker1Claimed)
        // let staker1PendingReward = web3.utils.fromWei(await tokenReleaseInt.lockedBalances(staker1));
        // console.log("staker1 Pending reward=",staker1PendingReward);

        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        console.log("====================================================================================")
    })

    it("[0022] check staker1 withdraw reward,should pass", async()=>{

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));


        let preTeamBalance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let preTeamBalance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));

        let preBalance = web3.utils.fromWei(await melt.balanceOf(staker1));
        let pngpreBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));

        //res = await farmproxyinst.getAllClaimableReward(0,staker1)
        //console.log("all claimable reward:", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.withdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));
        console.log("====================================================================================")

    })

    it("[0023] check locked and pending balance,should pass", async()=>{

        time.increase(4*day+1);

        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        console.log("====================================================================================")
    })

    it("[0024] check staker1 withdraw reward,should pass", async()=>{

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));


        let preTeamBalance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let preTeamBalance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));

        let preBalance = web3.utils.fromWei(await melt.balanceOf(staker1));
        let pngpreBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));

        // res = await farmproxyinst.getAllClaimableReward(0,staker1)
        // console.log("all claimable reward:", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.withdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));

        console.log("====================================================================================")
    })

    it("[0025] check locked and pending balance,should pass", async()=>{
        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        console.log("====================================================================================")
    })
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    it("[0030] check staker1 withdraw lp,should pass", async()=>{
        time.increase(2000);

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("allpending=",res[0].toString(),res[1].toString(),res[2].toString());
        let stakeAmount = res[0];


        let preTeamBalance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let preTeamBalance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));

        let preBalance = web3.utils.fromWei(await melt.balanceOf(staker1));
        let pngpreBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));

        let lpprebalance = web3.utils.fromWei(await lp.balanceOf(staker1));

        res = await farmproxyinst.withdraw(0,stakeAmount,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));

        let lpafterbalance = web3.utils.fromWei(await lp.balanceOf(staker1));
        console.log("lp get back=" + (lpafterbalance - lpprebalance));

    })


//////////////////////////////////////////////////////////////////////////////////////////////////////////

    it("[0040] team withdraw reward,should pass", async()=>{
        let preBalance1 = web3.utils.fromWei(await melt.balanceOf(teamMember1));
        let preBalance2 = web3.utils.fromWei(await melt.balanceOf(teamMember2));

        let res = await teamReward.claimReward({from:teamMember1});
        assert.equal(res.receipt.status,true);

        res = await teamReward.claimReward({from:teamMember2});
        assert.equal(res.receipt.status,true);


        let afterBalance1 = web3.utils.fromWei(await melt.balanceOf(teamMember1));
        let afterBalance2 = web3.utils.fromWei(await melt.balanceOf(teamMember2));

        console.log("teamMember1 reward got=",afterBalance1-preBalance1);
        console.log("teamMember2 reward got=",afterBalance2-preBalance2);
    })
//////////////////////////////////////////////////////////////////////////////////
    it("[0050] check locked and pending balance,should pass", async()=>{
        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        console.log("====================================================================================")
    })

    it("[0051] user withdraw reward in emergency,should pass", async()=>{
        let preBalance1 = web3.utils.fromWei(await melt.balanceOf(staker1));
        let preBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2));
        console.log(preBalance1);

        let res = await tokenReleaseInt.setHalt(true);
        assert.equal(res.receipt.status,true);

        // res = await tokenReleaseInt.emergencyGetbackLeft();
        //   assert.equal(res.receipt.status,true);

        //console.log(res);
        // res = await tokenReleaseInt.emergencyGetbackLeft({from:staker2});
        // assert.equal(res.receipt.status,true);

        let afterBalance1 = web3.utils.fromWei(await melt.balanceOf(staker1));
        let afterBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2));

        console.log("staker1 reward got=",afterBalance1-preBalance1);
        console.log("staker2 reward got=",afterBalance2-preBalance2);


    })

})
