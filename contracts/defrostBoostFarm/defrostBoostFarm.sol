pragma solidity ^0.5.16;
import "./defrostBoostFarmStorage.sol";
import "../modules/IERC20.sol";
import "../modules/SafeMath.sol";
import "../modules/SafeERC20.sol";
import "../modules/proxyOwner.sol";

interface ITeamRewardSC {
    function inputTeamReward(uint256 _amount) external;
}

interface IReleaseSC {
    function releaseToken(address account,uint256 amount) external;
    function getClaimAbleBalance(address account) external view returns (uint256);
    function dispatchTimes() external view returns (uint256);
    function lockedBalanceOf(address account) external view returns(uint256);
    function userFarmClaimedBalances(address account) external view returns (uint256);
}

interface ITokenFarmSC {
    function stake(address account) external;
    function unstake(address account) external;
    function getReward(address account) external;
    function earned(address account)  external view returns(uint256);
    function getMineInfo() external view returns (uint256,uint256);
}


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


contract DefrostFarm is defrostBoostFarmStorage,proxyOwner{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event QuitDefrostReward(address to, uint256 amount);
    event QuitExtReward(address extFarmAddr, address rewardToken, address to, uint256 amount);
    event UpdatePoolInfo(uint256 pid, uint256 bonusEndBlock, uint256 rewardPerBlock);
    event WithdrawDefrostReward(address to, uint256 amount);
    event DoubleFarmingEnable(uint256 pid, bool flag);
    event SetExtFarm(uint256 pid, address extFarmAddr, uint256 extPid );
    event EmergencyWithdraw(uint256 indexed pid);

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event GetBackLeftRewardToken(address to, uint256 amount);

    event BoostDeposit(address indexed user,  uint256 amount);
    event BoostWithdraw(address indexed user, uint256 amount);

    constructor(address _multiSignature,address _origin0,address _origin1)
        proxyOwner(_multiSignature,_origin0,_origin1)
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
        uint256 extPid,
        uint256 extRewardPerShare,
        uint256 extTotalDebtReward,
        bool extEnableClaim,
        uint256 extAccPerShare){

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        return (
            pool.extFarmInfo.extFarmAddr,
            pool.extFarmInfo.extEnableDeposit,
            pool.extFarmInfo.extPid,
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
             ) public onlyOrigin {

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
                extPid: 0,
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
            onlyOrigin
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

            if(pool.extFarmInfo.extFarmAddr == address(0x0) || pool.extFarmInfo.extFarmAddr != extFarmAddr) continue;

            allTotalUnclaimed = pool.currentSupply.mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(pool.extFarmInfo.extTotalDebtReward).add(allTotalUnclaimed);

        }

        return allTotalUnclaimed;
    }

    function distributeFinalExtReward(uint256 _pid, uint256 _amount) public onlyOrigin {

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.extFarmInfo.extFarmAddr != address(0x0),"pool not supports double farming");

        uint256 allUnClaimedExtReward = totalUnclaimedExtFarmReward(pool.extFarmInfo.extFarmAddr);

        uint256 extRewardCurrentBalance = IERC20(IChef(pool.extFarmInfo.extFarmAddr).joe()).balanceOf(address(this));

        uint256 maxDistribute = extRewardCurrentBalance.sub(allUnClaimedExtReward);

        require(_amount <= maxDistribute,"distibute too much external rewards");

        pool.extFarmInfo.extRewardPerShare = _amount.mul(1e12).div(pool.currentSupply).add(pool.extFarmInfo.extRewardPerShare);
    }

    function getExtFarmRewardRate(IChef chef,IERC20 lpToken, uint256 extPid) internal view returns(uint256 rate){
//        uint256 multiplier = chef.getMultiplier(block.number-1, block.number);

        uint256 extRewardPerBlock = chef.joePerSec();

        (,uint256 allocPoint,uint256 lastRewardTimestamp,) = chef.poolInfo(extPid);
        //changed according joe
        uint256 multiplier = block.timestamp.sub(lastRewardTimestamp);

        uint256 totalAllocPoint = chef.totalAllocPoint();
        uint256 totalSupply = lpToken.balanceOf(address(chef));

        rate = multiplier.mul(extRewardPerBlock).mul(allocPoint).mul(1e12).div(totalAllocPoint).div(totalSupply);
    }

    function extRewardPerBlock(uint256 _pid) public view returns(uint256) {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(!pool.extFarmInfo.extEnableDeposit) return 0;

        IChef chef = IChef(pool.extFarmInfo.extFarmAddr);
        uint256 rate = getExtFarmRewardRate(chef, IERC20(pool.lpToken),pool.extFarmInfo.extPid);
        (uint256 amount,) = chef.userInfo(_pid,address(this));
        uint256 extReward = rate.mul(amount).div(1e12);

        return extReward;
    }
    
    function allPendingReward(uint256 _pid,address _user) public view returns(uint256,uint256,uint256){
        uint256 depositAmount;
        uint256 deFrostReward;
        uint256 joeReward;
        
       (depositAmount, deFrostReward) = pendingDefrostReward(_pid,_user);
        joeReward = pendingExtReward(_pid,_user);
        
        return (depositAmount, deFrostReward, joeReward);
    }

    function enableDoubleFarming(uint256 _pid, bool enable) public onlyOrigin {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.extFarmInfo.extFarmAddr != address(0x0),"pool not supports double farming yet");
        if(pool.extFarmInfo.extEnableDeposit != enable){

            uint256 oldJoeRewarad = IERC20(IChef(pool.extFarmInfo.extFarmAddr).joe()).balanceOf(address(this));

            if(enable){
                IERC20(pool.lpToken).approve(pool.extFarmInfo.extFarmAddr,0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
                if(pool.currentSupply > 0) {
                    IChef(pool.extFarmInfo.extFarmAddr).deposit(pool.extFarmInfo.extPid,pool.currentSupply);
                }

                pool.extFarmInfo.extEnableClaim = true;

            }else{
                IERC20(pool.lpToken).approve(pool.extFarmInfo.extFarmAddr,0);
                (uint256 amount,) = IChef(pool.extFarmInfo.extFarmAddr).userInfo(pool.extFarmInfo.extPid,address(this));
                if(amount > 0){
                    IChef(pool.extFarmInfo.extFarmAddr).withdraw(pool.extFarmInfo.extPid,amount);
                }
            }

            if(pool.currentSupply > 0){
                uint256 deltaJoeReward = IERC20(IChef(pool.extFarmInfo.extFarmAddr).joe()).balanceOf(address(this)).sub(oldJoeRewarad);

                pool.extFarmInfo.extRewardPerShare = deltaJoeReward.mul(1e12).div(pool.currentSupply).add(pool.extFarmInfo.extRewardPerShare);
            }

            pool.extFarmInfo.extEnableDeposit = enable;

            emit DoubleFarmingEnable(_pid,enable);
        }

    }

    function setDoubleFarming(uint256 _pid,address extFarmAddr,uint256 _extPid) public onlyOrigin {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        require(extFarmAddr != address(0x0),"extFarmAddr == 0x0");
        PoolInfo storage pool = poolInfo[_pid];

       // require(pool.extFarmInfo.extFarmAddr == address(0x0),"cannot set extFramAddr again");

        uint256 extPoolLength = IChef(extFarmAddr).poolLength();
        require(_extPid < extPoolLength,"bad _extPid");

        (address lpToken,,,) = IChef(extFarmAddr).poolInfo(_extPid);
        require(lpToken == address(pool.lpToken),"pool mismatch between deFrostFarm and extFarm");

        pool.extFarmInfo.extFarmAddr = extFarmAddr;
        pool.extFarmInfo.extPid = _extPid;

        emit SetExtFarm(_pid, extFarmAddr, _extPid);

    }

    function disableExtEnableClaim(uint256 _pid)public onlyOrigin {
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
            (uint256 totalPendingJoe,,,) = IChef(pool.extFarmInfo.extFarmAddr).pendingTokens(pool.extFarmInfo.extPid,address(this));
            extRewardPerShare = totalPendingJoe.mul(1e12).div(pool.currentSupply).add(extRewardPerShare);
        }

        uint256 userPendingJoe = user.amount.mul(extRewardPerShare).div(1e12).sub(user.extRewardDebt);

        return userPendingJoe;
    }

    function depositLPToChef(uint256 _pid,uint256 _amount) internal {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;

        UserInfo storage user =  userInfo[_pid][msg.sender];

        if(pool.extFarmInfo.extEnableDeposit){

            uint256 oldJoeRewarad = IERC20(IChef(pool.extFarmInfo.extFarmAddr).joe()).balanceOf(address(this));
            uint256 oldTotalDeposit = pool.currentSupply.sub(_amount);

            IChef(pool.extFarmInfo.extFarmAddr).deposit(pool.extFarmInfo.extPid, _amount);

            uint256 deltaJoeReward = IERC20(IChef(pool.extFarmInfo.extFarmAddr).joe()).balanceOf(address(this));
            deltaJoeReward = deltaJoeReward.sub(oldJoeRewarad);

            if(oldTotalDeposit > 0 && deltaJoeReward > 0){
                pool.extFarmInfo.extRewardPerShare = deltaJoeReward.mul(1e12).div(oldTotalDeposit).add(pool.extFarmInfo.extRewardPerShare);
            }

        }

        if(pool.extFarmInfo.extEnableClaim) {
            uint256 transferJoeAmount = user.amount.sub(_amount).mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(user.extRewardDebt);

            if(transferJoeAmount > 0){
                address JoeToken = IChef(pool.extFarmInfo.extFarmAddr).joe();
                IERC20(JoeToken).safeTransfer(msg.sender,transferJoeAmount);
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

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;

        if(pool.extFarmInfo.extEnableDeposit){

            require(user.amount >= _amount,"withdraw too much lpToken");

            uint256 oldJoeRewarad = IERC20(IChef(pool.extFarmInfo.extFarmAddr).joe()).balanceOf(address(this));
            uint256 oldTotalDeposit = pool.currentSupply;

            IChef(pool.extFarmInfo.extFarmAddr).withdraw(pool.extFarmInfo.extPid, _amount);

            uint256 deltaJoeReward = IERC20(IChef(pool.extFarmInfo.extFarmAddr).joe()).balanceOf(address(this)).sub(oldJoeRewarad);
            if(oldTotalDeposit > 0 && deltaJoeReward > 0)
                pool.extFarmInfo.extRewardPerShare = deltaJoeReward.mul(1e12).div(oldTotalDeposit).add(pool.extFarmInfo.extRewardPerShare);

        }

        if(pool.extFarmInfo.extEnableClaim) {
            uint256 transferJoeAmount = user.amount.mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(user.extRewardDebt);

            if(transferJoeAmount > 0){
                address JoeToken = IChef(pool.extFarmInfo.extFarmAddr).joe();
                IERC20(JoeToken).safeTransfer(msg.sender, transferJoeAmount);
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

        //move to here
        updatePool(_pid);

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


    function emergencyWithdrawExtLp(uint256 _pid) public onlyOrigin {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;

        IChef(pool.extFarmInfo.extFarmAddr).emergencyWithdraw(pool.extFarmInfo.extPid);

        pool.extFarmInfo.extEnableDeposit = false;            

        emit EmergencyWithdraw(_pid);
    }

    // Safe defrost transfer function, just in case if rounding error causes pool to not have enough defrost reward.
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBal = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > rewardBal) {
            IERC20(rewardToken).safeTransfer(_to, rewardBal);
        } else {
            IERC20(rewardToken).safeTransfer(_to, _amount);
        }
    }

    function quitDefrostFarm(address _to) public onlyOrigin {
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

    function quitExtFarm(address extFarmAddr, address _to) public onlyOrigin {
        require(_to != address(0), "_to == 0");
        require(extFarmAddr != address(0), "extFarmAddr == 0");

        IERC20 joeToken = IERC20(IChef(extFarmAddr).joe());

        uint256 joeBalance = joeToken.balanceOf(address(this));

        uint256 totalUnclaimedReward = totalUnclaimedExtFarmReward(extFarmAddr);

        require(totalUnclaimedReward <= joeBalance, "extreward shortage");

        uint256 quitBalance = joeBalance.sub(totalUnclaimedReward);

        joeToken.safeTransfer(_to, quitBalance);

        emit QuitExtReward(extFarmAddr,address(joeToken),_to, quitBalance);
    }

    function getBackLeftRewardToken(address _to) public onlyOrigin {
        require(_to != address(0), "_to == 0");
        uint256 rewardTokenBal = IERC20(rewardToken).balanceOf(address(this));
        safeRewardTransfer(_to, rewardTokenBal);
        emit GetBackLeftRewardToken(_to, rewardTokenBal);
    }

    function setDefrostAddress( address _rewardToken,
                                address _oracle,
                                address _h2o,
                                address _teamRewardSc,
                                address _releaseSc,
                                address _tokenFarm)
        public onlyOrigin
    {
        require(_rewardToken!=address(0),"_rewardToken address is 0");
        require(_oracle!=address(0),"_rewardToken address is 0");
        require(_teamRewardSc!=address(0),"_rewardToken address is 0");
        require(_releaseSc!=address(0),"_rewardToken address is 0");

        rewardToken = _rewardToken;
        oracle = _oracle;
        h2o = _h2o;
        teamRewardSc = _teamRewardSc;
        releaseSc = _releaseSc;

        /////////////////////////////////////////////////////
        tokenFarm = _tokenFarm;
        IERC20(h2o).approve(address(tokenFarm),uint256(-1));
    }

    function totalStaked(uint256 _pid) public view returns (uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        return pool.currentSupply;
    }

    function getMineInfo(uint256 _pid) public view returns (uint256,uint256,uint256,uint256,uint256) {
        return (poolmineinfo[_pid].totalMineReward,poolmineinfo[_pid].duration,
           poolInfo[_pid].bonusStartBlock,poolInfo[_pid].rewardPerBlock,poolInfo[_pid].bonusStartTime);
    }

////////////////////////////////////////////////////////////////////////////////////////////////

    function setFixedTeamRatio(uint256 _ratio)
        public onlyOrigin
    {
        fixedTeamRatio = _ratio;
    }

    function setFixedWhitelistPara(uint256 _incRatio,uint256 _whiteListfloorLimit)
       public onlyOrigin
    {
        //_incRatio,0 whiteList increase will stop
        fixedWhitelistRatio = _incRatio;
        whiteListfloorLimit = _whiteListfloorLimit;
    }

    function setWhiteList(address[] memory _user)
        public onlyOrigin
    {
        require(_user.length>0,"array length is 0");
        for(uint256 i=0;i<_user.length;i++) {
            whiteListLpUserInfo[_user[i]] = true;
        }
    }

    function setWhiteListMemberStatus(address _user,bool _status)
        public onlyOrigin
    {
        whiteListLpUserInfo[_user] = _status;
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////

    function getUserRewardAndTeamReward(uint256 _pid,address _user, uint256 _reward)
            public view returns(uint256,uint256)
    {
        uint256 userIncRatio = RATIO_DENOM;

        UserInfo storage user = userInfo[_pid][_user];
        //current stake must be over minimum require lp amount
        if (whiteListLpUserInfo[_user]&&user.amount >= whiteListfloorLimit) {
            userIncRatio = userIncRatio.add(fixedWhitelistRatio);
        }

        uint256 userRward = _reward.mul(userIncRatio).div(RATIO_DENOM);

        //boost user balance;
        uint256 userBoostFactor = getUserBoostFactor(balances[_user]);
        userRward = userRward.mul(userBoostFactor).div(RATIO_DENOM);

        //get team reward
        uint256 teamReward = userRward.mul(fixedTeamRatio).div(RATIO_DENOM);

        //get user reward
        userRward = userRward.sub(teamReward);

        return (userRward,teamReward);
    }

    function mintUserRewardAndTeamReward(uint256 _pid,address _user, uint256 _reward) internal {

        uint256 userRward = 0;
        uint256 teamReward = 0;

        (userRward,teamReward) = getUserRewardAndTeamReward(_pid,_user,_reward);

        if(teamReward>0) {
            IERC20(rewardToken).approve(teamRewardSc,teamReward);
            ITeamRewardSC(teamRewardSc).inputTeamReward(teamReward);
        }

        IERC20(rewardToken).approve(releaseSc,userRward);
        IReleaseSC(releaseSc).releaseToken(_user,userRward);
    }

    //function lockedBalanceOf(address account) external view returns(uint256);
   // function userFarmClaimedBalances(address account) external view returns (uint256);

    function getRewardInfo(uint256 _pid,address _user)  public view returns(uint256,uint256,uint256,uint256,uint256) {
        uint256 depositAmount;
        uint256 deFrostReward;
        uint256 joeReward;

        (depositAmount,deFrostReward,joeReward) = allPendingReward(_pid,_user);

        uint256 distimes = IReleaseSC(releaseSc).dispatchTimes();

        uint256 claimable = deFrostReward.div(distimes);
        uint256 locked = IReleaseSC(releaseSc).lockedBalanceOf(_user);
        locked = locked.add(deFrostReward.sub(claimable));

        claimable = claimable.add(IReleaseSC(releaseSc).getClaimAbleBalance(_user));

        uint256 claimed = IReleaseSC(releaseSc).userFarmClaimedBalances(_user);

        return (depositAmount,claimable,locked,claimed,joeReward);

    }
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function setBoostFarmFactorPara(uint256 _BaseBoostTokenAmount,uint256 _BaseIncreaseRatio,uint256 _BoostTokenAmountStepAmount,uint256 _RatioIncreaseStep)
        external
        onlyOrigin
    {
        BaseBoostTokenAmount = _BaseBoostTokenAmount;
        BaseIncreaseRatio = _BaseIncreaseRatio; //3%

        RatioIncreaseStep = _RatioIncreaseStep;// 1%
        BoostTokenAmountStepAmount = _BoostTokenAmountStepAmount;
    }

    function boostDeposit(uint256 _amount) notHalted nonReentrant external {
        require(_amount > 0, "cannot stake 0");

        IERC20(smelt).safeTransferFrom(msg.sender,address(this), _amount);

        totalsupply = totalsupply.add(_amount);
        balances[msg.sender] = balances[msg.sender].add(_amount);
        //update token mine
        ITokenFarmSC(tokenFarm).stake(msg.sender);

        emit BoostDeposit(msg.sender,_amount);

    }

    function boostwithdraw( uint256 _amount) notHalted nonReentrant external{
        if(_amount ==0) {

            ITokenFarmSC(tokenFarm).getReward(msg.sender);

        } else {
            totalsupply = totalsupply.sub(_amount);
            balances[msg.sender] = balances[msg.sender].sub(_amount);

            //updated token mine
            ITokenFarmSC(tokenFarm).unstake(msg.sender);

            IERC20(smelt).safeTransfer(msg.sender, _amount);

            emit BoostWithdraw(msg.sender, _amount);
        }
    }

    function getUserBoostFactor(uint256 _amount)
        public view returns(uint256)
    {

        if(_amount<BaseBoostTokenAmount) {
            return RATIO_DENOM;
        } else {
            uint256 ratio = (_amount.sub(BaseBoostTokenAmount).div(BoostTokenAmountStepAmount)).mul(RatioIncreaseStep);//no decimal,just integer multiple
            return RATIO_DENOM.add(BaseIncreaseRatio).add(ratio);
        }
    }

    function boostStakedFor(address _account) public view returns (uint256) {
        return balances[_account];
    }

    function boostPendingReward(address _account) public view returns(uint256){
        return ITokenFarmSC(tokenFarm).earned(_account);
    }

    function boostTotalStaked() public view returns (uint256){
        return totalsupply;
    }

    function getBoostMineInfo() public view returns (uint256,uint256) {
        return ITokenFarmSC(tokenFarm).getMineInfo();
    }

    function balanceOf(address _account) external view returns (uint256) {
        return balances[_account];
    }

    function totalSupply() external view returns (uint256){
        return totalsupply;
    }

}

