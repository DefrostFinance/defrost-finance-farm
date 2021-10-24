pragma solidity ^0.5.16;
import "../modules/SafeMath.sol";
import "../modules/IERC20.sol";
import "../modules/proxyOwner.sol";
import "./defrostTeamDistributeStorage.sol";

/**
 * @title FPTCoin is finnexus collateral Pool token, implement ERC20 interface.
 * @dev ERC20 token. Its inside value is collatral pool net worth.
 *
 */
contract TeamDistribute is defrostTeamDistributeStorage,proxyOwner {

    using SafeMath for uint256;
    modifier inited (){
    	  require(rewardToken !=address(0));
    	  _;
    }

    constructor(address _multiSignature,address origin0,address origin1,
                address _rewardToken)
        proxyOwner(_multiSignature,origin0,origin1)
        public
    {
        rewardToken = _rewardToken;
    }

    /**
     * @dev getting back the left mine token
     * @param reciever the reciever for getting back mine token
     */
    function getbackLeftReward(address reciever)  public onlyOrigin {
        uint256 bal =  IERC20(rewardToken).balanceOf(address(this));
        IERC20(rewardToken).transfer(reciever,bal);
    }  

    function setMultiUsersInfo( address[] memory users,
                                uint256[] memory ratio)
        public
        inited
        OwnerOrOrigin
    {
        require(users.length==ratio.length);
        uint256 totalRatio = 0;

        userCount = 0;//reset to zero
        for(uint256 i=0;i<users.length;i++){
            require(users[i]!=address(0),"user address is 0");
            require(ratio[i]>0,"ratio should be bigger than 0");
            require(ratio[i]<=RATIO_DENOM,"ratio should be bigger than 0");

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
        onlyOrigin
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
        onlyOrigin
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
        require(amount>0,"pending amount need to be bigger than 0");

        allUserInfo[idx].pendingAmount = 0;

        //transfer back to user
        uint256 balbefore = IERC20(rewardToken).balanceOf(msg.sender);
        IERC20(rewardToken).transfer(msg.sender,amount);
        uint256 balafter = IERC20(rewardToken).balanceOf(msg.sender);
        require((balafter.sub(balbefore))==amount,"error transfer melt,balance check failed");
    }

    function inputTeamReward(uint256 _amount)
        public
        inited
    {
        require(_amount>0);
        IERC20(rewardToken).transferFrom(msg.sender,address(this),_amount);

        for(uint256 i=0;i<userCount;i++){
            userInfo storage info = allUserInfo[i];
            uint256 useramount = _amount.mul(info.ratio).div(RATIO_DENOM);
            info.pendingAmount = info.pendingAmount.add(useramount);
            info.wholeAmount = info.wholeAmount.add(useramount);
        }
    }
    
}
