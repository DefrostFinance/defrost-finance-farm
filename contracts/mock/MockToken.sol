// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;


import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts/ownership/Ownable.sol";


// WaspToken
contract MockToken is ERC20, Ownable {
    string public name;
    uint256 public decimal;
    string public symbol;

    constructor(string memory _name,string memory _symbol,uint256 _decimal) public {
        name = _name;
        symbol = _symbol;
        decimal = _decimal;
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (WanSwapFarm).
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}