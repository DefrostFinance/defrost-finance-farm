pragma solidity ^0.5.16;
import "../modules/Halt.sol";
import "../modules/Admin.sol";
import "../modules/multiSignatureClient.sol";
import "../modules/Operator.sol";

contract defrostTeamDistributeStorage is Halt,Operator,multiSignatureClient {
    uint256 RATIO_DENOM = 100;
    struct userInfo {
        address user;
        uint256 ratio;
        uint256 wholeAmount;
        uint256 pendingAmount;
        bool    disable;
    }
    address public rewardToken;  //defrost token address

    uint256 userCount;
    mapping (uint256 => userInfo) public allUserInfo;//converting tx record for each user
    mapping (address => uint256) public allUserIdx;
}