pragma solidity =0.5.16;
import "./SafeMath.sol";
import "./IERC20.sol";
import "./defrostTeamDistributeStorage.sol";


/**
 * @title FPTCoin is finnexus collateral Pool token, implement ERC20 interface.
 * @dev ERC20 token. Its inside value is collatral pool net worth.
 *
 */
contract TeamDistribute is defrostTeamDistributeStorage {

    using SafeMath for uint256;
    modifier inited (){
    	  require(rewardToken !=address(0));
    	  _;
    }

    constructor(address _multiSignature)
        multiSignatureClient(_multiSignature)
        public
    {
    }

    /**
     * @dev getting back the left mine token
     * @param reciever the reciever for getting back mine token
     */
    function getbackLeftReward(address reciever)  public onlyOperator(0) validCall {
        uint256 bal =  IERC20(rewardToken).balanceOf(address(this));
        IERC20(rewardToken).transfer(reciever,bal);
    }  

    function setMultiUsersInfo( address[] memory users,
                                uint256[] memory ratio)
        public
        inited
        onlyOperator(0)
    {
        require(users.length==ratio.length);
        uint256 totalRatio = 0;

        userCount = 0;//reset to zero
        for(uint256 i=0;i<users.length;i++){
            require(users[i]!=address(0),"user address is 0");
            require(ratio[i]>0,"ration should be bigger than 0");
            totalRatio += ratio[i];
            allUserIdx[users[i]] = userCount;
            allUserInfo[userCount] = userInfo(users[i],ratio[i],0,0,false);
            userCount++;
        }

        require(totalRatio==RATIO_DENOM);
    }

    function ressetUserRatio(address user,uint256 ratio)
        public
        inited
        onlyOperator(0)
    {
        require(ratio<RATIO_DENOM);
        uint256 idx = allUserIdx[user];
        RATIO_DENOM -= allUserInfo[idx].ratio;
        RATIO_DENOM += ratio;
        allUserInfo[idx].ratio = ratio;
    }

    function setUserStatus(address user,bool status)
        public
        inited
        onlyOperator(0)
        validCall
    {
        require(user != address(0));
        uint256 idx = allUserIdx[msg.sender];
        allUserInfo[idx].disable = status;
    }

    function claimableBalanceOf(address user) public view returns (uint256) {
        uint256 idx = allUserIdx[user];
        return allUserInfo[idx].pendingAmount;
    }

    function claimReward() public inited notHalted {
        uint256 idx = allUserIdx[msg.sender];
        require(!allUserInfo[idx].disable,"user is diabled already");

        uint256 amount = allUserInfo[idx].pendingAmount;
        allUserInfo[idx].pendingAmount = 0;

        //transfer back to user
        uint256 balbefore = IERC20(rewardToken).balanceOf(msg.sender);
        IERC20(rewardToken).transfer(msg.sender,amount);
        uint256 balafter = IERC20(rewardToken).balanceOf(msg.sender);
        require((balafter-balbefore)==amount,"error transfer phx,balance check failed");
    }

    function distribute(uint256 _amount)
        public
        onlyAdmin
    {
        require(_amount>0);
        for(uint256 i=0;i<userCount;i++){
            userInfo storage info = allUserInfo[i];
            uint256 useramount = _amount.mul(info.ratio).div(RATIO_DENOM);
            info.pendingAmount += useramount;
            info.wholeAmount += useramount;
        }
    }
    
}
