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
        userWhiteList[0x3cB3677A47f1A6174e30E4243ADCA402f2D3b9B4] = 100_000_000 + 100_000_000 + 89_824_544 + 27_271_388;
        userWhiteList[0xF6dCA0B3AE21661Ef12FF8d78ED38C5e493c0721] = 211_689_602;
        userWhiteList[0x7DF26Bd5601422B394E2A7b8B9063c0e0590fA89] = 1654_037_723;
        //for test
        userWhiteList[0xa86C1F667720C9a0b1691C199A62147309A72160] = 1_000_000;
    }


    function getbackToken(address _token,address _reciever)  public onlyOwner {
        uint256 bal =  IERC20(_token).balanceOf(address(this));
        if(bal>0) {
            IERC20(_token).safeTransfer(_reciever,bal);
        }
    }  
    

    function setWhiteList(address[] memory _accounts,uint256[] memory _tokenBals) public onlyOwner {
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