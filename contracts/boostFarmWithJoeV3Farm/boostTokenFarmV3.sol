pragma solidity ^0.5.16;

import "./boostTokenFarmDataV3.sol";
import "../modules/Halt.sol";
import "../modules/ReentrancyGuard.sol";
import "../modules/Operator.sol";
import "../modules/Admin.sol";
import "../modules/Ownable.sol";
import "../modules/SafeMath.sol";
import "../modules/IERC20.sol";
import "../modules/SafeERC20.sol";
import "../modules/Address.sol";
import "../modules/proxyOwner.sol";

contract BoostTokenFarmV3 is Halt, BoostTokenFarmDataV3,proxyOwner{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event RewardPaid(address rewardToken,address indexed user, uint256 reward);

    modifier onlyBoostFarm() {
        require(boostFarm==msg.sender, "not admin");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;     
        }
        _;
    }

    constructor(address _multiSignature,
                address _origin0,
                address _origin1,
                address _boostFarm,
                address _rewardToken)
      proxyOwner(_multiSignature,_origin0,_origin1)
      public
    {
        boostFarm = _boostFarm;
        rewardToken = _rewardToken;
    }

    function setPoolToken(address _boostFarm,address _rewardToken) public onlyOrigin {
        boostFarm = _boostFarm;
        rewardToken = _rewardToken;
    }

    function setMineRate(uint256 _reward,uint256 _duration) public onlyOrigin updateReward(address(0)){
        require(_duration>0,"duration need to be over 0");
        rewardRate = _reward.div(_duration);
        rewardPerduration = _reward;
        duration = _duration;
    }

    //need set start time  as same as boostFarm
    function setPeriodFinish(uint256 _startime,uint256 _endtime) public onlyOrigin updateReward(address(0)) {
        require(_startime>now);
        require(_endtime>_startime);

        //set new finish time
        lastUpdateTime = _startime;
        periodFinish = _endtime;
        startTime = _startime;
    }  
    
    /**
     * @dev getting back the left mine token
     * @param reciever the reciever for getting back mine token
     */
    function getbackLeftMiningToken(address reciever)  public
        onlyOrigin
    {
        uint256 bal =  IERC20(rewardToken).balanceOf(boostFarm);
        IERC20(rewardToken).safeTransferFrom(boostFarm,reciever,bal);
    }

//////////////////////////public function/////////////////////////////////    

    function lastTimeRewardApplicable() public view returns(uint256) {

        //get max
         uint256 timestamp = block.timestamp>startTime?block.timestamp:startTime;

         //get min
         return (timestamp<periodFinish?timestamp:periodFinish);
     }

    function rewardPerToken() public view returns(uint256) {
        if (IERC20(boostFarm).totalSupply() == 0 || now < startTime) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(IERC20(boostFarm).totalSupply())
        );
    }

    function earned(address account)  public view returns(uint256) {
        return IERC20(boostFarm).balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getReward(address account) public updateReward(account) onlyBoostFarm {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            IERC20(rewardToken).safeTransferFrom(boostFarm,account, reward);
            emit RewardPaid(rewardToken,account, reward);
        }
    }

    function getMineInfo() public view returns (uint256,uint256) {
        return (rewardPerduration,duration);
    }

//    function stake(address account) public updateReward(account) onlyBoostFarm {
//        require(startTime>0,"farm is not inited");
//    }
//
    function unstake(address account) public updateReward(account) onlyBoostFarm {
    }

}
