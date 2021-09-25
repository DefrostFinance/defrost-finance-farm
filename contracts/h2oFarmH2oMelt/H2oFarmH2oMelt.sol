
pragma solidity ^0.5.16;

import "../SafeMath.sol";
import "../IERC20.sol";
import "../Halt.sol";
import "../multiSignatureClient.sol";
import "../Operator.sol";
import "../ReentrancyGuard.sol";
import "./TokenFarm.sol";
import "./LPTokenWrapper.sol";

contract H2oFarmH2oMelt  is LPTokenWrapper,multiSignatureClient,Operator,Halt,ReentrancyGuard{
    address[] public rewardTokens;
    mapping(address=>TokenFarm) public tokenFarms;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event HisReward(address indexed user, uint256 indexed reward,uint256 indexed idx);

    constructor(address _multiSignature,address _stakeToken,address[] memory _rewardTokens)
        multiSignatureClient(_multiSignature)
        public
    {
        stakeToken = _stakeToken;
        for(uint256 i=0;i<_rewardTokens.length;i++) {
            rewardTokens.push(_rewardTokens[i]);
            tokenFarms[_rewardTokens[i]] = new TokenFarm(address(this),_rewardTokens[i]);
        }
    }


    function setMineRate(uint256 _pid,uint256 _reward,uint256 _duration) public onlyOwner{
        tokenFarms[rewardTokens[_pid]].setMineRate(_reward,_duration);
    }
//
    function setPeriodFinish(uint256 _pid,uint256 startime,uint256 endtime)public onlyOwner {
         tokenFarms[rewardTokens[_pid]].setPeriodFinish(startime,endtime);
    }

    function getbackLeftMiningToken(uint256 _pid,address reciever)  public
        onlyOperator(0)
        validCall
    {
        tokenFarms[rewardTokens[_pid]].getbackLeftMiningToken(reciever);
    }


    function rewardPerToken(uint256 _pid) public view returns(uint256) {
        return tokenFarms[rewardTokens[_pid]].rewardPerToken();
    }


    function earned(uint256 _pid,address account) internal view returns(uint256) {
        return tokenFarms[rewardTokens[_pid]].earned(account);
    }

//    //keep same name with old version
    function totalRewards(uint256 _pid,address account) public view returns(uint256) {
        return tokenFarms[rewardTokens[_pid]].totalRewards(account);
    }
//
    function stake(uint256 amount,bytes memory data) public notHalted nonReentrant {
        super.stake(amount);
        for(uint256 i=0;i<rewardTokens.length;i++) {
            tokenFarms[rewardTokens[i]].stake(msg.sender);
        }
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount,bytes memory data) public notHalted nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        for(uint256 i=0;i<rewardTokens.length;i++) {
            tokenFarms[rewardTokens[i]].unstake(msg.sender);
        }
        emit Withdrawn(msg.sender, amount);
    }

    function exit() public notHalted nonReentrant {
        super.unstake(balanceOf(msg.sender));
        for(uint256 i=0;i<rewardTokens.length;i++) {
            tokenFarms[rewardTokens[i]].exit(msg.sender);
        }
    }

    function getReward() public notHalted nonReentrant {
        for(uint256 i=0;i<rewardTokens.length;i++) {
            tokenFarms[rewardTokens[i]].getReward(msg.sender);
        }
    }

//    /**
//     * @return Total number of distribution tokens balance.
//     */
    function distributionBalance() public view returns (uint256,uint256) {
        if(rewardTokens.length>=2) {
            uint256 balance1 =  tokenFarms[rewardTokens[0]].distributionBalance();
            uint256 balance2 =  tokenFarms[rewardTokens[1]].distributionBalance();
            return (balance1,balance2);
        } else {
            return (0,0);
        }

    }
//
//    /**
//     * @param addr The user to look up staking information for.
//     * @return The number of staking tokens deposited for addr.
//     */
    function totalStakedFor(address _account) public view returns (uint256) {
        return super.balanceOf(_account);
    }


//    ////////////////////////////compitable with previous interface for UI///////////////////////////////////////////////////////////
    function deposit(uint256 _pid, uint256 _amount)  public payable {
        bytes memory data = new bytes(1);
        stake(_amount,data);
    }
//
    function withdraw(uint256 _pid, uint256 _amount) public payable{
        if(_amount==0) {
            getReward();
        }else {
            bytes memory data = new bytes(1);
            unstake(_amount,data);
        }
    }

    function allPendingReward(uint256 _pid,address _user) public view returns(uint256){
        return earned(_pid,_user);
    }

    function totalStaked(uint256 _pid) public view returns (uint256){
        return super.totalSupply();
    }

    function getMineInfo(uint256 _pid) public view returns (uint256,uint256) {
        return tokenFarms[rewardTokens[_pid]].getMineInfo();
    }

}