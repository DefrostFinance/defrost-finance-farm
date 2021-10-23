pragma solidity =0.5.16;

import "../SafeMath.sol";
import "../IERC20.sol";

contract LPTokenWrapper {

    uint256 internal totalsupply;
    mapping(address => uint256) internal balances;
    address public stakeToken;
    
    using SafeMath for uint256;

    function totalSupply() public view returns(uint256) {
        return totalsupply;
    }

    function balanceOf(address account) public view returns(uint256) {
        return balances[account];
    }

    function stake(uint256 amount) internal {

        require(amount > 0, "cannot stake 0");
        uint256 preBalance = IERC20(stakeToken).balanceOf(address(this));
        IERC20(stakeToken).transferFrom(msg.sender,address(this), amount);
        uint256 afterBalance = IERC20(stakeToken).balanceOf(address(this));
        require(afterBalance-preBalance==amount,"token stake transfer error!");

        totalsupply = totalsupply.add(amount);
        balances[msg.sender] = balances[msg.sender].add(amount);
    }

    function unstake (uint256 amount) internal {
        totalsupply = totalsupply.sub(amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        uint256 preBalance = IERC20(stakeToken).balanceOf(address(this));
        IERC20(stakeToken).transfer(msg.sender, amount);
        uint256 afterBalance = IERC20(stakeToken).balanceOf(address(this));
        require(preBalance - afterBalance==amount,"token unstake transfer error!");
    }

    
}