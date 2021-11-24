pragma solidity =0.5.16;

import "../modules/Operator.sol";
import "../modules/Halt.sol";

contract AirDropVaultData is Operator,Halt {
    address public meltToken;

    uint256 public totalWhiteListAirdrop;
    uint256 public totalWhiteListClaimed;

    mapping (address=>uint256) public userWhiteList; //user=>airdrop amount
    event WhiteListClaim(address indexed claimer, uint256 indexed amount);
}