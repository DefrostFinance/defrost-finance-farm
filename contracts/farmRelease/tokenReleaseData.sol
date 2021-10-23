pragma solidity ^0.5.16;
import "../modules/Halt.sol";

contract tokenReleaseData is Halt {
    uint256 constant internal currentVersion = 2;
    function implementationVersion() public pure returns (uint256) 
    {
        return currentVersion;
    }
    //the locjed reward info
    struct lockedReward {
        uint256 startTime; //this tx startTime for locking
        uint256 total;     //record input amount in each lock tx    
        mapping (uint256 => uint256) alloc;//the allocation table
    }
    
    struct lockedIdx {
        uint256 beginIdx;//the first index for user converting input claimable tx index 
        uint256 totalIdx;//the total number for converting tx
    }

    address public meltAddress;  //token address
    uint256 public idxperiod = 24*3600;
    uint256 public timeSpan = 30*24*3600;//time interval span time ,default one month
    uint256 public dispatchTimes = 6;    //allocation times,default 6 times
    uint256 public txNum = 100; //100 times transfer tx 
    uint256 public lockPeriod = dispatchTimes*timeSpan;
    
    //the user's locked total balance
    mapping (address => uint256) public lockedBalances;//locked balance for each user
    
    mapping (address =>  mapping (uint256 => lockedReward)) public lockedAllRewards;//converting tx record for each user
    
    mapping (address => lockedIdx) public lockedIndexs;//the converting tx index info

    mapping (address => uint256[]) public userTxIdxs;//address idx number

    mapping (address => uint256) public userFarmClaimedBalances;//locked balance for each user

    event Input(address indexed sender,address indexed reciever, uint256 indexed amount,uint256 divAmount);

    event Claim(address indexed sender,uint256 indexed amount,uint256 indexed txcnt);

}