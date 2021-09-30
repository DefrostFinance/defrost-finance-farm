pragma solidity 0.5.16;

import "../Halt.sol";
import "../ReentrancyGuard.sol";
import "../multiSignatureClient.sol";
import "../Operator.sol";

contract defrostFarmErrorReporter {
    enum Error {
        NO_ERROR,
        UNAUTHORIZED
    }

    enum FailureInfo {
        ACCEPT_ADMIN_PENDING_ADMIN_CHECK,
        ACCEPT_PENDING_IMPLEMENTATION_ADDRESS_CHECK,
        SET_PENDING_ADMIN_OWNER_CHECK,
        SET_PENDING_IMPLEMENTATION_OWNER_CHECK
    }

    /**
      * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
      * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
      **/
    event Failure(uint error, uint info, uint detail);

    /**
      * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
      */
    function fail(Error err, FailureInfo info) internal returns (uint) {
        emit Failure(uint(err), uint(info), 0);

        return uint(err);
    }

    /**
      * @dev use this when reporting an opaque error from an upgradeable collaborator contract
      */
    function failOpaque(Error err, FailureInfo info, uint opaqueError) internal returns (uint) {
        emit Failure(uint(err), uint(info), opaqueError);

        return uint(err);
    }
}

contract defrostPangalinStorage is multiSignatureClient,Operator,Halt, ReentrancyGuard{
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 extRewardDebt; 
    }

    struct ExtFarmInfo{
        address extFarmAddr;
        address rewardToken;
        bool extEnableDeposit;
        uint256 extRewardPerShare;
        uint256 extTotalDebtReward;  //
        bool extEnableClaim;
    }

    struct PoolMineInfo {
        uint256 totalMineReward;
        uint256 duration;
    }

    uint256 RATIO_DENOM = 1000;
    struct whiteListRewardRatio {
        uint256 amount;
        uint256 incPercent;
    }

    struct teamRewardRatio {
        uint256 amount;
        uint256 percent;
    }


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


    uint256 teamRewardLevels;
    mapping (uint256 => teamRewardRatio) teamRewardInfo;

    uint256 whiteListRewardIncLevels;
    mapping (uint256 => whiteListRewardRatio)  public whiteListRewardIncInfo;

    mapping (address => uint256) public whiteListLpUserInfo;

    //use cPhx
    address public rewardToken;
    address public oracle;
    address public usx;
    address public teamRewardReciever;
    uint256 public fixedTeamRatio;
    uint256 public fixedWhitelistRatio;

    mapping (uint256=>PoolMineInfo) public poolmineinfo;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;// Info of each user that stakes LP tokens.
    PoolInfo[] poolInfo;   // Info of each pool.
}