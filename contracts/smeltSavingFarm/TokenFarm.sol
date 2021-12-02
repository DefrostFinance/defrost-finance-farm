pragma solidity ^0.5.16;

import "./TokenFarmData.sol";
import "../modules/Halt.sol";
import "../modules/ReentrancyGuard.sol";
import "../modules/Operator.sol";
import "../modules/Admin.sol";
import "../modules/Ownable.sol";
import "../modules/SafeMath.sol";
import "../modules/IERC20.sol";
import "../modules/SafeERC20.sol";
import "../modules/Address.sol";
import "../modules/Admin.sol";

contract TokenFarm is Halt,TokenFarmData,Admin {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event RewardPaid(address rewardToken,address indexed user, uint256 reward);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;     
        }
        _;
    }

    constructor(address _manager,address _rewardToken)
      public
    {
        manager = _manager;
        rewardToken = _rewardToken;
    }

    function setMineRate(uint256 _reward,uint256 _duration) public onlyAdmin updateReward(address(0)){
        require(_duration>0,"duration need to be over 0");
        rewardRate = _reward.div(_duration);
        rewardPerduration = _reward;
        duration = _duration;
    }   


    function setPeriodFinish(uint256 _startime,uint256 _endtime) public onlyAdmin updateReward(address(0)) {
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
        onlyAdmin
    {
        uint256 bal =  IERC20(rewardToken).balanceOf(manager);
        IERC20(rewardToken).safeTransferFrom(manager,reciever,bal);
    }

//////////////////////////public function/////////////////////////////////    

    function lastTimeRewardApplicable() public view returns(uint256) {

        //get max
         uint256 timestamp = block.timestamp>startTime?block.timestamp:startTime;

         //get min
         return (timestamp<periodFinish?timestamp:periodFinish);
     }

    function rewardPerToken() public view returns(uint256) {
        if (IERC20(manager).totalSupply() == 0 || now < startTime) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(IERC20(manager).totalSupply())
        );
    }

    function earned(address account)  public view returns(uint256) {
        return IERC20(manager).balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getReward(address account) public updateReward(account) onlyAdmin {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            IERC20(rewardToken).safeTransferFrom(manager,account, reward);
            emit RewardPaid(rewardToken,account, reward);
        }
    }

    function update(address account) public updateReward(account) onlyAdmin {
    }

    function getMineInfo() public view returns (uint256,uint256) {
        return (rewardPerduration,duration);
    }

}
