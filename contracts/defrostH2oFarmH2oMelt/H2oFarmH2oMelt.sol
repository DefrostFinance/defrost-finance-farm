
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

    uint256 constant public REWARD_NUM = 2;

    address[] public rewardTokens;
    mapping(address=>TokenFarm) public tokenFarms;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _multiSignature,address _stakeToken,address[] memory _rewardTokens)
        multiSignatureClient(_multiSignature)
        public
    {
        require(_rewardTokens.length==REWARD_NUM);

        require(_multiSignature != address(0));
        require(_stakeToken != address(0));

        stakeToken = _stakeToken;
        for(uint256 i=0;i<_rewardTokens.length;i++) {
            rewardTokens.push(_rewardTokens[i]);
            tokenFarms[_rewardTokens[i]] = new TokenFarm(address(this),_rewardTokens[i]);
            IERC20(_rewardTokens[i]).approve(address(tokenFarms[_rewardTokens[i]]),0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }
    }

    function setMineRate(uint256 _pid,uint256 _reward,uint256 _duration) public onlyOwner{
        require(_pid<REWARD_NUM);
        require(_reward>0);
        require(_duration>0);

        tokenFarms[rewardTokens[_pid]].setMineRate(_reward,_duration);
    }
//
    function setPeriodFinish(uint256 _pid,uint256 _startime,uint256 _endtime)public onlyOwner {
         require(_pid<REWARD_NUM);
         require(_startime>now);
         require(_endtime>_startime);

         tokenFarms[rewardTokens[_pid]].setPeriodFinish(_startime,_endtime);
    }

    function getbackLeftMiningToken(address reciever)  public
        onlyOperator(0)
        validCall
    {
        for(uint256 i=0;i<rewardTokens.length;i++) {
            tokenFarms[rewardTokens[i]].getbackLeftMiningToken(reciever);
        }

    }


    function rewardPerToken(uint256 _pid) public view returns(uint256) {
        return tokenFarms[rewardTokens[_pid]].rewardPerToken();
    }


    function earned(uint256 _pid,address account) internal view returns(uint256) {
        return tokenFarms[rewardTokens[_pid]].earned(account);
    }


    function getMineInfo(uint256 _pid) public view returns (uint256,uint256) {
        return tokenFarms[rewardTokens[_pid]].getMineInfo();
    }

    function allPendingReward(uint256 _pid,address _user) public view returns(uint256){
        return earned(_pid,_user);
    }

    function totalStaked() public view returns (uint256){
        return super.totalSupply();
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
//     * @param addr The user to look up staking information for.
//     * @return The number of staking tokens deposited for addr.
//     */
    function totalStakedFor(address _account) public view returns (uint256) {
        return super.balanceOf(_account);
    }


//////////////////////////////compitable with previous interface for UI///////////////////////////////////////////////////////////
    function deposit(uint256 _amount)  public payable {
        stake(_amount);

        for(uint256 i=0;i<rewardTokens.length;i++) {
            tokenFarms[rewardTokens[i]].stake(msg.sender);
        }

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public payable{
        if(_amount==0) {
            getReward();
        }else {
            unstake(_amount);
            for(uint256 i=0;i<rewardTokens.length;i++) {
                tokenFarms[rewardTokens[i]].unstake(msg.sender);
            }
            emit Withdrawn(msg.sender, _amount);
        }
    }


}