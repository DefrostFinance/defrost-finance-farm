pragma solidity 0.5.16;
import "./defrostPangalinStorage.sol";
import "../IERC20.sol";
import "../SafeMath.sol";
import "../SafeERC20.sol";

interface IOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface ITeamRewardSC {
    function distribute(uint256 _amount) external;
}

interface ILpToken {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IMint {
    function mint(address account, uint256 amount) external;
}

interface IDecimals {
    function decimals() external view returns (uint8);
}

interface IPangalinFarm {
    function getReward() external;
    function withdraw(uint256 amount) external;
    function stake(uint256 amount) external ;
    function earned(address account) external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function rewardRate() external view returns(uint256);
    function exit() external;
}

interface IPangalinManager {
    function stakes(address lptoken) external view returns (address);
   // mapping(address => address) public stakes;
    function weights(address lptoken) external view returns (uint);
}

contract defrostPangalinFarm is defrostPangalinStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event QuitDefrostReward(address to, uint256 amount);
    event QuitExtReward(address extFarmAddr, address rewardToken, address to, uint256 amount);
    event UpdatePoolInfo(uint256 pid, uint256 bonusEndBlock, uint256 rewardPerBlock);
    event WithdrawDefrostReward(address to, uint256 amount);
    event DoubleFarmingEnable(uint256 pid, bool flag);
    event SetExtFarm(uint256 pid, address extFarmAddr, address rewardToken);
    event EmergencyWithdraw(uint256 indexed pid);

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event GetBackLeftRewardToken(address to, uint256 amount);

    constructor(address _multiSignature)
        multiSignatureClient(_multiSignature)
        public
    {

    }

    function getPoolInfo(uint256 _pid) external view returns (
        address lpToken,         // Address of LP token contract.
        uint256 currentSupply,    //
        uint256 bonusStartBlock,  //
        uint256 newStartBlock,    //
        uint256 bonusEndBlock,    // Block number when bonus defrost period ends.
        uint256 lastRewardBlock,  // Last block number that defrost distribution occurs.
        uint256 accRewardPerShare,// Accumulated defrost per share, times 1e12. See below.
        uint256 rewardPerBlock,   // defrost tokens created per block.
        uint256 totalDebtReward) {

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        return (
            address(pool.lpToken),
            pool.currentSupply,
            pool.bonusStartBlock,
            pool.newStartBlock,
            pool.bonusEndBlock,
            pool.lastRewardBlock,
            pool.accRewardPerShare,
            pool.rewardPerBlock,
            pool.totalDebtReward
            );

    }
    
    function getExtFarmInfo(uint256 _pid) external view returns (
		address extFarmAddr,  
        bool extEnableDeposit,
        address rewardToken,
        uint256 extRewardPerShare,
        uint256 extTotalDebtReward,
        bool extEnableClaim,
        uint256 extAccPerShare){

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        return (
            pool.extFarmInfo.extFarmAddr,
            pool.extFarmInfo.extEnableDeposit,
            pool.extFarmInfo.rewardToken,
            pool.extFarmInfo.extRewardPerShare,
            pool.extFarmInfo.extTotalDebtReward,
            pool.extFarmInfo.extEnableClaim,
            pool.extFarmInfo.extRewardPerShare);

    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(address _lpToken,
                 uint256 _bonusStartTime,
                 uint256 _bonusEndBlock,
                 uint256 _rewardPerBlock,
                 uint256 _totalMineReward,
                 uint256 _duration,
                 uint256 _secPerBlk
             ) public onlyOperator(1) {

        require(block.number < _bonusEndBlock, "block.number >= bonusEndBlock");
        //require(_bonusStartBlock < _bonusEndBlock, "_bonusStartBlock >= _bonusEndBlock");
        require(block.timestamp<_bonusStartTime,"start time is earlier than current time");
        //estimate entime
        uint256 endTime = block.timestamp.add((_bonusEndBlock.sub(block.number)).mul(_secPerBlk));
        require(_bonusStartTime<endTime,"estimate end time is early than start time");

        require(address(_lpToken) != address(0), "_lpToken == 0");

        //uint256 lastRewardBlock = block.number > _bonusStartBlock ? block.number : _bonusStartBlock;

        ExtFarmInfo memory extFarmInfo = ExtFarmInfo({
                extFarmAddr:address(0x0),
                extEnableDeposit:false,
                rewardToken: address(0),
                extRewardPerShare: 0,
                extTotalDebtReward:0,
                extEnableClaim:false
                });


        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            currentSupply: 0,
            bonusStartBlock: 0,
            newStartBlock: 0,
            bonusEndBlock: _bonusEndBlock,
            lastRewardBlock: 0,
            accRewardPerShare: 0,
            rewardPerBlock: _rewardPerBlock,
            totalDebtReward: 0,
            bonusStartTime: _bonusStartTime,
            extFarmInfo:extFarmInfo
        }));


        PoolMineInfo memory pmi = PoolMineInfo({
            totalMineReward: _totalMineReward,
            duration:_duration
        });

        poolmineinfo[poolInfo.length-1] = pmi;
    }

    function updatePoolInfo(uint256 _pid,
                            uint256 _bonusEndBlock,
                            uint256 _rewardPerBlock,
                            uint256 _totalMineReward,
                            uint256 _duration)
            public
            onlyOperator(1)
    {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        require(_bonusEndBlock > block.number, "_bonusEndBlock <= block.number");
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        if(pool.bonusEndBlock <= block.number){
            pool.newStartBlock = block.number;
        }

        pool.bonusEndBlock = _bonusEndBlock;
        pool.rewardPerBlock = _rewardPerBlock;
        //keep it to later show
        poolmineinfo[_pid].totalMineReward = _totalMineReward;
        poolmineinfo[_pid].duration=_duration;

        emit UpdatePoolInfo(_pid, _bonusEndBlock, _rewardPerBlock);
    }

    function getMultiplier(uint256 _pid) internal view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        if(block.number <= pool.bonusStartBlock){
            return 0;// no begin
        }

        if(pool.lastRewardBlock >= pool.bonusEndBlock){
            return 0;// ended
        }

        if(block.number >= pool.bonusEndBlock){
            // ended, but no update, lastRewardBlock < bonusEndBlock
            return pool.bonusEndBlock.sub(pool.lastRewardBlock);
        }

        return block.number.sub(pool.lastRewardBlock);
    }

    // View function to see pending defrost on frontend.
    function pendingDefrostReward(uint256 _pid, address _user) public view returns (uint256,uint256) {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        if (block.number > pool.lastRewardBlock && pool.currentSupply != 0) {
            uint256 multiplier = getMultiplier(_pid);
            uint256 reward = multiplier.mul(pool.rewardPerBlock);
            accRewardPerShare = accRewardPerShare.add(reward.mul(1e12).div(pool.currentSupply));
        }

        // return (user.amount, user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt));//orginal
       uint256 pendingReward = user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);

       (pendingReward,) = getUserRewardAndTeamReward(_pid,_user,pendingReward);

       return (user.amount,pendingReward);

    }

    /////////////////////////////////////////////////////////////////////////////////////////
    function totalUnclaimedExtFarmReward(address extFarmAddr) public view returns(uint256){
        
        uint256 allTotalUnclaimed = 0; 
        
        for (uint256 index = 0; index < poolInfo.length; index++) {
            PoolInfo storage pool = poolInfo[index];

            if(pool.extFarmInfo.extFarmAddr == address(0x0) || pool.extFarmInfo.extFarmAddr != extFarmAddr) {
                continue;
            }

            allTotalUnclaimed = pool.currentSupply.mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(pool.extFarmInfo.extTotalDebtReward).add(allTotalUnclaimed);
            
        }

        return allTotalUnclaimed;
    }

    function distributeFinalExtReward(uint256 _pid, uint256 _amount) public onlyOperator(0) validCall {

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.extFarmInfo.extFarmAddr != address(0x0),"pool not supports double farming");

        uint256 allUnClaimedExtReward = totalUnclaimedExtFarmReward(pool.extFarmInfo.extFarmAddr);

        uint256 extRewardCurrentBalance = IERC20(pool.extFarmInfo.rewardToken).balanceOf(address(this));

        uint256 maxDistribute = extRewardCurrentBalance.sub(allUnClaimedExtReward);

        require(_amount <= maxDistribute,"distibute too much external rewards");

        pool.extFarmInfo.extRewardPerShare = _amount.mul(1e12).div(pool.currentSupply).add(pool.extFarmInfo.extRewardPerShare);
    }

    function extRewardRate(uint256 _pid) public view returns(uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(!pool.extFarmInfo.extEnableDeposit) return 0;

        address extstakeReward = IPangalinManager(pool.extFarmInfo.extFarmAddr).stakes(pool.lpToken);

        return IPangalinFarm(extstakeReward).rewardRate();
    }
    
    function allPendingReward(uint256 _pid,address _user) public view returns(uint256,uint256,uint256){
        uint256 depositAmount;
        uint256 deFrostReward;
        uint256 extReward;
        
       (depositAmount, deFrostReward) = pendingDefrostReward(_pid,_user);
        extReward = pendingExtReward(_pid,_user);
        
        return (depositAmount, deFrostReward, extReward);
    }

    function enableDoubleFarming(uint256 _pid, bool enable) public onlyOperator(1){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.extFarmInfo.extFarmAddr != address(0x0),"pool not supports double farming yet");

        if(pool.extFarmInfo.extEnableDeposit != enable){

            uint256 oldReward = IERC20(pool.extFarmInfo.rewardToken).balanceOf(address(this));
            address extstakeReward = IPangalinManager(pool.extFarmInfo.extFarmAddr).stakes(pool.lpToken);
            if(enable){
                IERC20(pool.lpToken).approve(pool.extFarmInfo.extFarmAddr,0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
                if(pool.currentSupply > 0) {
                   IPangalinFarm(extstakeReward).stake(pool.currentSupply);
                }
                pool.extFarmInfo.extEnableClaim = true;
            }else{
                IERC20(pool.lpToken).approve(extstakeReward,0);
                uint256 amount = IPangalinFarm(extstakeReward).earned(address(this));
                if(amount > 0){
                    IPangalinFarm(extstakeReward).getReward();
                    IPangalinFarm(extstakeReward).withdraw(amount);
                }
            }

            if(pool.currentSupply > 0){
                uint256 deltaReward = IERC20(pool.extFarmInfo.rewardToken).balanceOf(address(this)).sub(oldReward);
                pool.extFarmInfo.extRewardPerShare = deltaReward.mul(1e12).div(pool.currentSupply).add(pool.extFarmInfo.extRewardPerShare);
            }

            pool.extFarmInfo.extEnableDeposit = enable;
            emit DoubleFarmingEnable(_pid,enable);
        }

    }

    function setDoubleFarming(uint256 _pid,address extFarmAddr,address rewardToken) public onlyOperator(1){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        require(extFarmAddr != address(0x0),"extFarmAddr == 0x0");
        PoolInfo storage pool = poolInfo[_pid];

        address extStakeReward = IPangalinManager(extFarmAddr).stakes(pool.lpToken);
        require(extStakeReward != address(0));

        IERC20(pool.lpToken).approve(extStakeReward,~uint256(0));

        pool.extFarmInfo.extFarmAddr = extFarmAddr;
        pool.extFarmInfo.rewardToken = rewardToken;

        emit SetExtFarm(_pid, extFarmAddr, rewardToken);
    }

    function disableExtEnableClaim(uint256 _pid)public onlyOperator(1){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.extFarmInfo.extEnableDeposit == false, "can only disable extEnableClaim when extEnableDeposit is disabled");

        pool.extFarmInfo.extEnableClaim = false;
    }

    function pendingExtReward(uint256 _pid, address _user) public view returns(uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        if(pool.extFarmInfo.extFarmAddr == address(0x0)){
            return 0;
        }

        if(pool.currentSupply <= 0) return 0;

        UserInfo storage user = userInfo[_pid][_user];
        if(user.amount <= 0) return 0;
        
        uint256 extRewardPerShare = pool.extFarmInfo.extRewardPerShare;

        if(pool.extFarmInfo.extEnableDeposit){
            address extstakeReward = IPangalinManager(pool.extFarmInfo.extFarmAddr).stakes(pool.lpToken);
            uint256 totalPending = IPangalinFarm(extstakeReward).earned(address(this));
            extRewardPerShare = totalPending.mul(1e12).div(pool.currentSupply).add(extRewardPerShare);
        }

        uint256 userExtPending = user.amount.mul(extRewardPerShare).div(1e12).sub(user.extRewardDebt);

        return userExtPending;
    }

    function depositLPToChef(uint256 _pid,uint256 _amount) internal {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;
        
        UserInfo storage user =  userInfo[_pid][msg.sender];
        address extstakeReward = IPangalinManager(pool.extFarmInfo.extFarmAddr).stakes(pool.lpToken);

        if(pool.extFarmInfo.extEnableDeposit){
            uint256 oldReward = IERC20(pool.extFarmInfo.rewardToken).balanceOf(address(this));
            uint256 oldTotalDeposit = pool.currentSupply.sub(_amount);
            //deposit
            IPangalinFarm(extstakeReward).stake(_amount);
            IPangalinFarm(extstakeReward).getReward();
            uint256 deltaReward = IERC20(pool.extFarmInfo.rewardToken).balanceOf(address(this));
            if(deltaReward>oldReward) {
                deltaReward = deltaReward.sub(oldReward);
            } else {
                deltaReward = 0;
            }

            if(oldTotalDeposit > 0 && deltaReward > 0){
                pool.extFarmInfo.extRewardPerShare = deltaReward.mul(1e12).div(oldTotalDeposit).add(pool.extFarmInfo.extRewardPerShare);
            }

        }

        if(pool.extFarmInfo.extEnableClaim) {
            uint256 transferRewardAmount = user.amount.sub(_amount).mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(user.extRewardDebt);
            if(transferRewardAmount > 0){
                IERC20(pool.extFarmInfo.rewardToken).safeTransfer(msg.sender, transferRewardAmount);
            }
        }

        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.sub(user.extRewardDebt);
        user.extRewardDebt = user.amount.mul(pool.extFarmInfo.extRewardPerShare).div(1e12);
        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.add(user.extRewardDebt);
    }

    function withDrawLPFromExt(uint256 _pid,uint256 _amount) internal{
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user =  userInfo[_pid][msg.sender];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) {
            return;
        }

        if(pool.extFarmInfo.extEnableDeposit){
            
            require(user.amount >= _amount,"withdraw too much lpToken");

            uint256 oldExtRewarad = IERC20(pool.extFarmInfo.rewardToken).balanceOf(address(this));

            uint256 oldTotalDeposit = pool.currentSupply;
            address extstakeReward = IPangalinManager(pool.extFarmInfo.extFarmAddr).stakes(pool.lpToken);
            IPangalinFarm(extstakeReward).getReward();

            if(_amount>0)  {
                IPangalinFarm(extstakeReward).withdraw(_amount);
            }

            uint256 deltaReward = IERC20(pool.extFarmInfo.rewardToken).balanceOf(address(this));
            if(deltaReward>oldExtRewarad) {
                deltaReward = deltaReward.sub(oldExtRewarad);
            }

            if(oldTotalDeposit > 0 && deltaReward > 0)
                pool.extFarmInfo.extRewardPerShare = deltaReward.mul(1e12).div(oldTotalDeposit).add(pool.extFarmInfo.extRewardPerShare);
            
        }

        if(pool.extFarmInfo.extEnableClaim) {
            uint256 transferAmount = user.amount.mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(user.extRewardDebt);

            if(transferAmount > 0){
                IERC20(pool.extFarmInfo.rewardToken).safeTransfer(msg.sender, transferAmount);
            }
        }
        
        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.sub(user.extRewardDebt);
        user.extRewardDebt = user.amount.sub(_amount).mul(pool.extFarmInfo.extRewardPerShare).div(1e12);
        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.add(user.extRewardDebt);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.currentSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(_pid);
        uint256 reward = multiplier.mul(pool.rewardPerBlock);
        pool.accRewardPerShare = pool.accRewardPerShare.add(reward.mul(1e12).div(pool.currentSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for defrost reward allocation.
    function deposit(uint256 _pid, uint256 _amount) public  notHalted nonReentrant {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        //to set start block number at init start
        require(block.timestamp>pool.bonusStartTime,"not reach start time for farming");
        if(pool.bonusStartBlock==0
           &&pool.newStartBlock==0
           &&pool.lastRewardBlock==0) {
            pool.bonusStartBlock = block.number;
            pool.newStartBlock = block.number;
            pool.lastRewardBlock = block.number;
        }

        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                //IERC20(rewardToken).transfer(msg.sender, pending);//original
                mintUserRewardAndTeamReward(_pid,msg.sender,pending);
            }
        }

        if(_amount > 0) {
            IERC20(pool.lpToken).safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.currentSupply = pool.currentSupply.add(_amount);
        }

        //move to here
        updatePool(_pid);

        // must excute after lpToken has beem transfered from user to this contract and the amount of user depoisted is updated.
        depositLPToChef(_pid,_amount);
            
        pool.totalDebtReward = pool.totalDebtReward.sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        pool.totalDebtReward = pool.totalDebtReward.add(user.rewardDebt);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public notHalted nonReentrant {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        withDrawLPFromExt(_pid,_amount);

        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            //IERC20(rewardToken).transfer(msg.sender, pending);
            mintUserRewardAndTeamReward(_pid,msg.sender,pending);
        }

        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.currentSupply = pool.currentSupply.sub(_amount);
            IERC20(pool.lpToken).safeTransfer(address(msg.sender), _amount);
        }

        pool.totalDebtReward = pool.totalDebtReward.sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        pool.totalDebtReward = pool.totalDebtReward.add(user.rewardDebt);

        emit Withdraw(msg.sender, _pid, _amount);
    }


    function emergencyWithdrawExtLp(uint256 _pid) public onlyOperator(0) validCall {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;

        address extstakeReward = IPangalinManager(pool.extFarmInfo.extFarmAddr).stakes(pool.lpToken);
        IPangalinFarm(extstakeReward).exit();

        pool.extFarmInfo.extEnableDeposit = false;            

        emit EmergencyWithdraw(_pid);
    }

    // Safe defrost transfer function, just in case if rounding error causes pool to not have enough defrost reward.
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBal = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > rewardBal) {
            IERC20(rewardToken).transfer(_to, rewardBal);
        } else {
            IERC20(rewardToken).transfer(_to, _amount);
        }
    }

    function quitDefrostFarm(address _to) public onlyOperator(0) validCall {
        require(_to != address(0), "_to == 0");
        uint256 rewardTokenBal = IERC20(rewardToken).balanceOf(address(this));
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            require(block.number > pool.bonusEndBlock, "quitPhx block.number <= pid.bonusEndBlock");
            updatePool(pid);
            uint256 reward = pool.currentSupply.mul(pool.accRewardPerShare).div(1e12).sub(pool.totalDebtReward);
            rewardTokenBal = rewardTokenBal.sub(reward);
        }
        safeRewardTransfer(_to, rewardTokenBal);
        emit QuitDefrostReward(_to, rewardTokenBal);
    }

    function quitExtFarm(address extRewardToken,address extFarmAddr,address _to) public onlyOperator(0) validCall {
        require(_to != address(0), "_to == 0");
        require(extRewardToken != address(0), "extFarmAddr == 0");

        uint256 rewardBalance = IERC20(extRewardToken).balanceOf(address(this));

        uint256 totalUnclaimedReward = totalUnclaimedExtFarmReward(extFarmAddr);

        require(totalUnclaimedReward <= rewardBalance, "extreward shortage");

        uint256 quitBalance = rewardBalance.sub(totalUnclaimedReward);

        IERC20(extRewardToken).safeTransfer(_to, quitBalance);

        emit QuitExtReward(rewardToken,address(rewardToken),_to, quitBalance);
    }

    function getBackLeftRewardToken(address _to) public onlyOperator(0) validCall {
        require(_to != address(0), "_to == 0");
        uint256 rewardTokenBal = IERC20(rewardToken).balanceOf(address(this));
        safeRewardTransfer(_to, rewardTokenBal);
        emit GetBackLeftRewardToken(_to, rewardTokenBal);
    }

    function setDefrostAddress( address _rewardToken,
                                address _oracle,
                                address _usx,
                                address _teamRewardReciever)
        public onlyOperator(1)
    {
        rewardToken = _rewardToken;
        oracle = _oracle;
        usx = _usx;
        teamRewardReciever = _teamRewardReciever;
    }

    function totalStaked(uint256 _pid) public view returns (uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        return pool.currentSupply;
    }

    function getMineInfo(uint256 _pid) public view returns (uint256,uint256,uint256,uint256) {
        return (poolmineinfo[_pid].totalMineReward,poolmineinfo[_pid].duration,
           poolInfo[_pid].bonusStartBlock,poolInfo[_pid].rewardPerBlock);
    }

    function getVersion() public pure returns (uint256) {
        return 1;
    }
////////////////////////////////////////////////////////////////////////////////////////////////
    function setWhiteListRewardIncRatio(uint256[] memory _amount,
                                        uint256[] memory _incPercent)
        public onlyOperator(1)
    {
        require(_amount.length==_incPercent.length,"array length is not equal");
        for(uint256 i=0;i<_amount.length;i++) {
           whiteListRewardIncInfo[whiteListRewardIncLevels++]=whiteListRewardRatio(_amount[i],_incPercent[i]);
        }
    }

    function setTeamRewardRatio(uint256[] memory _amount,
                                uint256[] memory _ratio)
        public onlyOperator(1)
    {
        require(_amount.length== _ratio.length,"array length is not equal");
        for(uint256 i=0;i<_amount.length;i++) {
            teamRewardInfo[teamRewardLevels++]=teamRewardRatio(_amount[i], _ratio[i]);
        }
    }

    function setFixedTeamRatio(uint256 _ratio)
        public onlyOperator(1)
    {
        fixedTeamRatio = _ratio;
    }

    function setWhiteList(address[] memory _user,
                          uint256[] memory _amount)
        public onlyOperator(1)
    {
        require(_user.length==_amount.length,"array length is not equal");
        for(uint256 i=0;i<_amount.length;i++) {
            whiteListLpUserInfo[_user[i]] = _amount[i];
        }
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////
    function getPriceTokenDecimal(address token) public view returns(uint256,uint256){
        uint256 decimal = 10**18;
        if(token!=address(0)) {
            decimal = (10**uint256(IDecimals(token).decimals()));
        }
       // return the price decimal and token decimal;
       return ((uint256(10**18).div(decimal).mul(10**8)),decimal);
    }


    function getLpTvlAndUserTvl(uint256 _pid,uint256 lpamount) public view returns (uint256,uint256) {
        address token = ILpToken(poolInfo[_pid].lpToken).token0();
        if(token==usx) {
            token = ILpToken(poolInfo[_pid].lpToken).token1();
        }

        uint256 balance = IERC20(token).balanceOf(poolInfo[_pid].lpToken);

        uint256 priceDecimal;
        uint256 tokenDecimal;
        (priceDecimal,tokenDecimal) = getPriceTokenDecimal(token);

        uint256 tvl = IOracle(oracle).getPrice(token).mul(balance).div(priceDecimal.mul(tokenDecimal));
        tvl = tvl*2;

        //tvl*(lpamout/lp totalSupply);
        uint256 usertvl = tvl.mul(lpamount).div(ILpToken(poolInfo[_pid].lpToken).totalSupply());

        return (tvl,usertvl);
    }

    function getWhiteListIncRatio(uint256 _pid,address _user) public view returns (uint256) {

        uint256 usertvl;
        uint256 ratio = 0;
        UserInfo memory user = userInfo[_pid][_user];
        (,usertvl) = getLpTvlAndUserTvl(_pid,user.amount);

        if(whiteListLpUserInfo[_user]>0) {
            for(uint256 i=0;i<whiteListRewardIncLevels;i++) {
                if( usertvl>=whiteListRewardIncInfo[i].amount) {
                    ratio = whiteListRewardIncInfo[i].incPercent;
                }
            }
            return (RATIO_DENOM+ratio);//return 1+increase persent
        } else {
            return RATIO_DENOM;
        }
    }


    function getTeamRewardRatio(uint256 _pid,address _user) public view returns (uint256) {
        if(fixedTeamRatio>0) {
            return fixedTeamRatio;
        } else {
            uint256 tvl;
            UserInfo memory user = userInfo[_pid][_user];
            (tvl,) = getLpTvlAndUserTvl(_pid,user.amount);
            uint256 ratio = 0;//at least, team reward is 1%
            for(uint256 i=0;i<teamRewardLevels;i++) {
                if(tvl>=teamRewardInfo[i].amount) {
                    ratio =teamRewardInfo[i].percent;
                }
            }
            return ratio;
        }
    }

    function getUserRewardAndTeamReward(uint256 _pid,address _user, uint256 _reward)
            public view returns(uint256,uint256)
    {
        uint256 userRatio = getWhiteListIncRatio(_pid,_user);
        uint256 userRward = _reward.mul(userRatio).div(RATIO_DENOM);

        uint256 teamRatio = getTeamRewardRatio(_pid,_user);
        uint256 teamReward = userRward.mul(teamRatio).div(RATIO_DENOM);

        userRward = userRward.sub(teamReward);

        return (userRward,teamReward);
    }

    function mintUserRewardAndTeamReward(uint256 _pid,address _user, uint256 _reward) internal {

        uint256 userRward = 0;
        uint256 teamReward = 0;

        (userRward,teamReward) = getUserRewardAndTeamReward(_pid,_user,_reward);

        if(teamReward>0) {
            IMint(rewardToken).mint(teamRewardReciever,teamReward);
            //safeRewardTransfer(teamRewardReciever,teamReward);
            ITeamRewardSC(teamRewardReciever).distribute(teamReward);
        }

        if(userRward>0) {
            IMint(rewardToken).mint(_user,userRward);
            //safeRewardTransfer(_user,teamReward);
        }
    }

}