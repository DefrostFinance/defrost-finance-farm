pragma solidity ^0.5.16;

import "./TokenFarmData.sol";
import "../modules/Halt.sol";
import "../modules/ReentrancyGuard.sol";
import "../modules/Operator.sol";
import "../modules/Admin.sol";
import "../modules/Ownable.sol";
import "../modules/SafeMath.sol";
import "../modules/IERC20.sol";
import "../modules/Address.sol";

contract TokenFarm is Halt,TokenFarmData {
    using SafeMath for uint256;

    event RewardPaid(address rewardToken,address indexed user, uint256 reward);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            require(now >= startTime,"not reach start time");
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

    function setMineRate(uint256 _reward,uint256 _duration) public onlyOwner updateReward(address(0)){
        rewardRate = _reward.div(_duration);
        rewardPerduration = _reward;
        duration = _duration;
    }   


    function setPeriodFinish(uint256 startime,uint256 endtime) public onlyOwner updateReward(address(0)) {
        //set new finish time
        lastUpdateTime = startime;
        periodFinish = endtime;
        startTime = startime;
    }  
    
    /**
     * @dev getting back the left mine token
     * @param reciever the reciever for getting back mine token
     */
    function getbackLeftMiningToken(address reciever)  public
        onlyOwner
    {
        uint256 bal =  IERC20(rewardToken).balanceOf(manager);
        IERC20(rewardToken).transferFrom(manager,reciever,bal);
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

    function getReward(address account) public updateReward(account) onlyOwner {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            uint256 preBalance = IERC20(rewardToken).balanceOf(address(manager));

            IERC20(rewardToken).transferFrom(manager,account, reward);

            uint256 afterBalance = IERC20(rewardToken).balanceOf(address(manager));
            require(preBalance - afterBalance==reward,"phx award transfer error!");
            emit RewardPaid(rewardToken,account, reward);
        }
    }

    function stake(address account) public updateReward(account) onlyOwner {
		 require(startTime>0,"farm is not inited");
         require(now>startTime);
    }

    function unstake(address account) public updateReward(account) onlyOwner {
    }

    function exit(address account) public onlyOwner {
        getReward(account);
    }

    function getMineInfo() public view returns (uint256,uint256) {
        return (rewardPerduration,duration);
    }

}
