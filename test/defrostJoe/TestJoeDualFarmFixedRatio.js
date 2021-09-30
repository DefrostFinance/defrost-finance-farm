const { time, expectEvent} = require("@openzeppelin/test-helpers");
const PoolProxy = artifacts.require('deforestFarmJoeProxy');
const MinePool = artifacts.require('defrostFarmJoeFixedRatio');

const LpToken = artifacts.require('LpToken');
const WethToken = artifacts.require('LpToken');

const Oracle = artifacts.require('Oracle');

const TeamDistribute = artifacts.require('TeamDistribute');
const TeamDistributeProxy = artifacts.require('DefrostTeamDistributeProxy');

const MeltToken = artifacts.require("DefrostToken");
const MultiSignature = artifacts.require("multiSignature");

const JoeFarmChef = artifacts.require("MasterChefJoeV2");
const JoeToken = artifacts.require('MockToken');

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
    let lp;//stake token
    let melt;
    let usx;
    let usdc;
    let teamReward;
    let mulSiginst;
    let oracleinst;
    let startTime;

    let joeFarmChefInst;
    let joeToken;

    async function initPngDoubleFarm(){
        // constructor(
        //     JoeToken _joe,
        //     address _devAddr,
        //     address _treasuryAddr,
        //     address _investorAddr,
        //     uint256 _joePerSec,
        //     uint256 _startTimestamp,
        //     uint256 _devPercent,
        //     uint256 _treasuryPercent,
        //     uint256 _investorPercent
        joeToken = await JoeToken.new("Joe token",18);

        joeFarmChefInst = await JoeFarmChef.new(joeToken.address,accounts[7],accounts[8],accounts[9],web3.utils.toWei("1",'ether'),startTime,0,0,0);

    //     function add(
    //         uint256 _allocPoint,
    //         IERC20 _lpToken,
    //         IRewarder _rewarder
    // ) public onlyOwner {

        let res = await joeFarmChefInst.add(100,lp.address,"0x0000000000000000000000000000000000000000");
        assert.equal(res.receipt.status,true);

    }

    async function enablePngDoubleFarm(){

        let res = await farmproxyinst.setDoubleFarming(0,joeFarmChefInst.address,0,{from:operator1});
        assert.equal(res.receipt.status,true);

        res = await farmproxyinst.enableDoubleFarming(0,true,{from:operator1});
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

        await lp.mint(staker1,VAL_1M);
        await lp.mint(staker2,VAL_1M);

        usx = await LpToken.new("usx",18);
        await usx.mint(lp.address,VAL_1M);

        usdc = await WethToken.new("lptoken",18);
        await usdc.mint(lp.address,VAL_1M);

        await lp.setReserve(usx.address,usdc.address);
/////////////////////////////reward token///////////////////////////////////////////
        melt = await MeltToken.new("melt token","melt",18,accounts[0],accounts[1],accounts[2],mulSiginst.address);

//set farm///////////////////////////////////////////////////////////
        farminst = await MinePool.new(mulSiginst.address);
        console.log("pool address:", farminst.address);

        farmproxyinst = farminst;
        //await PoolProxy.new(farminst.address,melt.address,mulSiginst.address);
        console.log("proxy address:",farmproxyinst.address);
        //set operator 0
        await farmproxyinst.setOperator(0,operator0);
        await farmproxyinst.setOperator(1,operator1);

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
            5,{from:operator1});
        assert.equal(res.receipt.status,true);

//  res = await farmproxyinst.setOperator(1,accounts[0]);
//  assert.equal(res.receipt.status,true);
/////////////////////////////////team reward sc set////////////////////////////
        console.log("team reward sc set");
        teamReward = await TeamDistribute.new(mulSiginst.address,melt.address);

        // let teamProxy = await TeamDistributeProxy.new(teamReward.address,melt.address,mulSiginst.address);
        // teamReward = await TeamDistribute.at(teamProxy.address);

        //set operator for setting
        res = await teamReward.setOperator(0,accounts[0]);
        assert.equal(res.receipt.status,true);
        //set contract to mint
        res = await teamReward.setOperator(1,farmproxyinst.address);
        assert.equal(res.receipt.status,true);

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
                                                    {from:operator1});

        assert.equal(res.receipt.status,true);

        //set whitelist ratio
        res = await farmproxyinst.setFixedWhitelistRatio(200,{from:operator1});
        assert.equal(res.receipt.status,true);

        //set whitelist
        res = await farmproxyinst.setWhiteList([staker1,staker2],[1,1],{from:operator1});
        assert.equal(res.receipt.status,true);

        //set team ratio
        // res = await farmproxyinst.setTeamRewardRatio([0,VAL_1M,VAL_10M,VAL_1B,VAL_10B],[10,35,5,6,65],{from:operator1});
        // assert.equal(res.receipt.status,true);

        res = await farmproxyinst.setFixedTeamRatio(10,{from:operator1});
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
        res = await lp.approve(farmproxyinst.address,VAL_1M,{from:staker1});
        assert.equal(res.receipt.status,true);

        // res = await lp.approve(joeStakeRewardInt.address,VAL_1M,{from:staker1});
        // assert.equal(res.receipt.status,true);

        time.increaseTo(startTime+1);

        let preBal = await joeToken.balanceOf(farmproxyinst.address);
        console.log("prebalance=",preBal.toString(10));
        res = await farmproxyinst.deposit(0,VAL_1M,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBal = await joeToken.balanceOf(farmproxyinst.address);
        console.log("afterbalance=",afterBal.toString(10));

        let mineInfo = await farmproxyinst.getMineInfo(0);
        console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
            mineInfo[2].toString(10),mineInfo[3].toString(10));
/////////////////////////////////////////////////////////////////////////////////
        time.increaseTo(startTime+1000);
        await lp.approve(farmproxyinst.address,VAL_1M,{from:staker2});
        res = await farmproxyinst.deposit(0,VAL_1M,{from:staker2});
        assert.equal(res.receipt.status,true);

        mineInfo = await farmproxyinst.getMineInfo(0);
        console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
            mineInfo[2].toString(10),mineInfo[3].toString(10));

        let block = await web3.eth.getBlock(mineInfo[2]);
        console.log("start block time",block.timestamp);

    })


    it("[0020] check staker1 mined balance,should pass", async()=>{
        time.increaseTo(startTime+2000);
        let res = await farmproxyinst.totalStaked(0);
        console.log("totalstaked=" + res);

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("allpending=",res[0].toString(),res[1].toString(),res[2].toString());

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
        let pngpreBalance = web3.utils.fromWei(await joeToken.balanceOf(staker1));

        res = await farmproxyinst.withdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await joeToken.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));

    })


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
        let pngpreBalance = web3.utils.fromWei(await joeToken.balanceOf(staker1));

        let lpprebalance = web3.utils.fromWei(await lp.balanceOf(staker1));

        res = await farmproxyinst.withdraw(0,stakeAmount,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await joeToken.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));

        let lpafterbalance = web3.utils.fromWei(await lp.balanceOf(staker1));
        console.log("lp get back=" + (lpafterbalance - lpprebalance));

    })

    it("[0040] team withdraw reward lp,should pass", async()=>{
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


})
