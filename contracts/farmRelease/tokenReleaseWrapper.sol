pragma solidity ^0.5.16;
import "../modules/IERC20.sol";
import "../modules/Ownable.sol";

interface IReleaseSc {
    function releaseToken(address account,uint256 amount) external;
}

contract tokenReleaseWrapper is Ownable{

    address  public meltToken;
    address  public releaseSc;

    constructor (address _meltToken,address _releaseSc)
    public
    {
        meltToken = _meltToken;
        releaseSc = _releaseSc;
        IERC20(meltToken).approve(releaseSc,uint256(-1));
    }

    function getbackLeftMelt(address _reciever)  public onlyOwner {
        uint256 bal =  IERC20(meltToken).balanceOf(address(this));
        if(bal>0) {
            IERC20(meltToken).transfer(_reciever,bal);
        }
    }

    function releaseToken() external {
        IReleaseSc(releaseSc).releaseToken(msg.sender,1);
    }
}