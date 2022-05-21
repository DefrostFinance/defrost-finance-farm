pragma solidity =0.5.16;
import "./AirdropVaultData.sol";
import "../modules/SafeMath.sol";
import "../modules/IERC20.sol";
import "../modules/SafeERC20.sol";

contract AirDropVault is AirDropVaultData {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor( address _token)
    public
    {
        token = _token;
    }


    function getbackToken(address _token,address _reciever)  public onlyOwner {
        uint256 bal =  IERC20(_token).balanceOf(address(this));
        if(bal>0) {
            IERC20(_token).safeTransfer(_reciever,bal);
        }
    }


    function setWhiteList(address[] memory _accounts,uint256[] memory _tokenBals) public onlyOperator(0) {
        require(_accounts.length== _tokenBals.length,"the input array length is not equal");
        uint256 i = 0;
        for(;i<_accounts.length;i++) {
            //just for tatics
            totalWhiteListAirdrop = totalWhiteListAirdrop.add(_tokenBals[i]);

            //accumulate user airdrop balance
            userWhiteList[_accounts[i]] = userWhiteList[_accounts[i]].add(_tokenBals[i]);

        }

    }


    function claimAirdrop() public {
        require(userWhiteList[msg.sender]>0);

        uint256 amount = userWhiteList[msg.sender];
        userWhiteList[msg.sender] = 0;
        //for statics
        totalWhiteListClaimed = totalWhiteListClaimed.add(amount);
        IERC20(token).safeTransfer(msg.sender,amount);

        emit WhiteListClaim(msg.sender,amount);
    }


    function balanceOfAirDrop(address _account) public view returns(uint256){
        return userWhiteList[_account];
    }

}