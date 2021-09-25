pragma solidity ^0.5.16;

import "./TokenFarmData.sol";
import "../Halt.sol";
import "../ReentrancyGuard.sol";
import "../Operator.sol";
import "../Admin.sol";
import "../Ownable.sol";
import "../SafeMath.sol";
import "../IERC20.sol";
import "../Address.sol";

contract TokenFarm is Halt,TokenFarmData {
    using SafeMath for uint256;

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

        require(_duration>0);
        //token number per seconds
        rewardRate = _reward.div(_duration);
         rewardPerduration = _reward;
        duration = _duration;

    }   


    function setPeriodFinish(uint256 startime,uint256 endtime) public onlyOwner updateReward(address(0)) {
        //the setting time must pass timebeing
        require(startime >=now);
        require(endtime > startTime);
        
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
        uint256 bal =  IERC20(rewardToken).balanceOf(address(this));
        IERC20(rewardToken).transfer(reciever,bal);
    }

//////////////////////////public function/////////////////////////////////    

    function lastTimeRewardApplicable() public view returns(uint256) {

        //get max
         uint256 timestamp = block.timestamp>startTime?block.timestamp:startTime;

         //get min
         return timestamp<periodFinish?timestamp:periodFinish;
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

    //keep same name with old version
    function totalRewards(address account) public view returns(uint256) {
        return earned(account);
    }


    function getReward(address account) public updateReward(account) onlyOwner {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            uint256 preBalance = IERC20(rewardToken).balanceOf(address(this));
            IERC20(rewardToken).transfer(account, reward);
            uint256 afterBalance = IERC20(rewardToken).balanceOf(address(this));
            require(preBalance - afterBalance==reward,"phx award transfer error!");
        }
    }

    function stake(address account) public updateReward(account) onlyOwner {
    }

    function unstake(address account) public updateReward(account) onlyOwner {
    }

    function exit(address account) public onlyOwner {
        getReward(account);
    }

    /**
     * @return Total number of distribution tokens balance.
     */
    function distributionBalance() public view returns (uint256) {
        return IERC20(rewardToken).balanceOf(address(this));
    }    


    function getMineInfo() public view returns (uint256,uint256) {
        return (rewardPerduration,duration);
    }


}
