pragma solidity ^0.5.16;
import "../modules/Halt.sol";
import "../modules/ReentrancyGuard.sol";
import "../modules/multiSignatureClient.sol";
import "../modules/Operator.sol";

contract FarmUsdcWithJoeV3Storage is Halt, ReentrancyGuard{
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 extRewardDebt; 
    }

    struct ExtFarmInfo{
        address extFarmAddr;
        bool extEnableDeposit;
        uint256 extPid;
        uint256 extRewardPerShare;
        uint256 extTotalDebtReward;  //
        bool extEnableClaim;
    }

    struct PoolMineInfo {
        uint256 totalMineReward;
        uint256 duration;
    }

    uint256 RATIO_DENOM = 1000;

    // Info of each pool.
    struct PoolInfo {
        address  lpToken;          // Address of LP token contract. 0
        uint256 currentSupply;    //1
        uint256 bonusStartBlock;  //2
        uint256 newStartBlock;    //3
        uint256 bonusEndBlock;    // Block number when bonus phx period ends.4
        uint256 lastRewardBlock;  // Last block number that phxs distribution occurs.5
        uint256 accRewardPerShare;// Accumulated phx per share, times 1e12. See below.6
        uint256 rewardPerBlock;   // phx tokens created per block.7
        uint256 totalDebtReward;  //8
        uint256 bonusStartTime;

        ExtFarmInfo extFarmInfo;

    }



    mapping (address => bool) public whiteListLpUserInfo;

    address public rewardToken;
    address public h2o;
    uint256 public fixedTeamRatio = 80;  //default 8%

    uint256 public fixedWhitelistRatio = 200;  //default 20%
    uint256 public whiteListfloorLimit = 500000 ether; //default 500 thousands

    address public teamRewardSc;
    address public releaseSc;

    mapping (uint256=>PoolMineInfo) public poolmineinfo;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;// Info of each user that stakes LP tokens.

    PoolInfo[] poolInfo;   // Info of each pool.

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    uint256 constant internal rayDecimals = 1000e18;//100%

    uint256 public BaseBoostTokenAmount = 1000e18;//1000 ether;
    uint256 public BaseIncreaseRatio = 30e18; //3%

    uint256 public RatioIncreaseStep = 10e18;// 1%
    uint256 public BoostTokenStepAmount = 1000e18;//1000 ether;

    uint256 public MaxFactor = 5500e18;//5.5 multiple


    address public smelt;
    uint256 internal totalsupply;
    mapping(address => uint256) internal balances;

    address public tokenFarm;

}