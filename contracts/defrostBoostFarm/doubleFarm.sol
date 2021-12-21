import "../modules/IERC20.sol";
import "../modules/SafeMath.sol";
import "../modules/SafeERC20.sol";
import "../modules/proxyOwner.sol";

interface IChef {
    function deposit(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
    // function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256);
    function pendingTokens(uint256 _pid, address _user)  external view returns (uint256,address,string memory,uint256);

    function joe() external view returns (address);
    function joePerSec() external view returns (uint256);

    function poolInfo(uint256) external  view returns ( address lpToken, uint256 allocPoint, uint256 lastRewardTime, uint256 accJoePerShare);
    function poolLength() external view returns (uint256);
    function totalAllocPoint() external view returns (uint256);
    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);
    function withdraw(uint256 _pid, uint256 _amount) external;
}

contract DoubleFarm {

    //todo
}