const { time, expectEvent} = require("@openzeppelin/test-helpers");

const LpToken = artifacts.require('LpToken');
const WethToken = artifacts.require('LpToken');

const Oracle = artifacts.require('Oracle');

const MeltToken = artifacts.require("DefrostToken");
const MultiSignature = artifacts.require("multiSignature");

const JoeFarmChef = artifacts.require("MasterChefJoeV2");
const JoeToken = artifacts.require('MockToken');

const AirDrop =  artifacts.require('AirDropVault');

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

    let operator0 = accounts[9];
    let operator1 = accounts[1]

    let disSpeed1 = web3.utils.toWei('1', 'ether');

    let VAL_1M = web3.utils.toWei('100', 'ether');

    let VAL_10M = web3.utils.toWei('100000', 'ether');
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
    let airdrop;

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
        melt = await MeltToken.new("melt token","melt",18,accounts[0],accounts[1],accounts[2]);

        airdrop = await AirDrop.new(melt.address);
        await airdrop.setOperator(0,accounts[0]);

        res = await melt.transfer(airdrop.address,VAL_10M,{from:accounts[0]});

        let users = [];
        let meltnum = [];
        for(var i=0;i<10;i++) {
            users.push(accounts[i]);
            if(i%2==0) {
                meltnum.push(web3.utils.toWei('2', 'ether'))
            } else {
                meltnum.push(web3.utils.toWei('1', 'ether'))
            }
        }

        await airdrop.setWhiteList(users,meltnum);
    })

    it("[0010] stake in,should pass", async()=>{
        for(var i=0;i<10;i++) {
            let airbal = await airdrop.balanceOfAirDrop(accounts[i]);
            console.log(i,"airdrop balance=",web3.utils.fromWei(airbal));

            let balbefore = await melt.balanceOf(accounts[i]);
            await airdrop.claimAirdrop({from: accounts[i]});
            let balafter = await melt.balanceOf(accounts[i]);

            diff =web3.utils.fromWei(balafter) -  web3.utils.fromWei(balbefore);

            console.log(i,"claimed airdrop=",diff)
        }
    })

    it("[0010] stake in,should pass", async()=>{
        let i = 0;
        let balbefore = await melt.balanceOf(accounts[i]);
        await airdrop.getbackLeftMelt(accounts[i],{from: accounts[i]});
        let balafter = await melt.balanceOf(accounts[i]);

        diff = web3.utils.fromWei(balafter) - web3.utils.fromWei(balbefore) ;

        console.log("get left token airdrop=",diff)
    })

 })
