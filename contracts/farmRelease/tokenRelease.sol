pragma solidity ^0.5.16;
import "./tokenReleaseData.sol";
import "../modules/SafeMath.sol";
import "../modules/IERC20.sol";
import "../modules/proxyOwner.sol";

/**
 * @title FPTCoin is finnexus collateral Pool token, implement ERC20 interface.
 * @dev ERC20 token. Its inside value is collatral pool net worth.
 *
 */
contract tokenRelease is tokenReleaseData,proxyOwner {
    using SafeMath for uint256;

    constructor (address multiSignature,address origin0,address origin1)
        proxyOwner(multiSignature,origin0,origin1)
        public
    {
    }

    modifier inited (){
    	  require(meltAddress !=address(0));
    	  _;
    }

    /**
     * @dev constructor function. set minePool contract address.
     */ 
    function setParameter(address _meltAddress,uint256 _timeSpan,uint256 _dispatchTimes,uint256 _txNum,uint256 _idxperiod) OwnerOrOrigin public{
        if (_meltAddress != address(0))
            meltAddress = _meltAddress;
            
        if (_timeSpan != 0) 
            timeSpan = _timeSpan;
            
        if (_dispatchTimes != 0) 
            dispatchTimes = _dispatchTimes;
        
        if (_txNum != 0) 
            txNum = _txNum;

        if(_idxperiod != 0) {
            idxperiod = _idxperiod;
        }

        lockPeriod = dispatchTimes*timeSpan;
    }
    
    /**
     * @dev getting back the left mine token
     */
    function emergencyGetbackLeft()  public isHalted {
        require(lockedBalances[msg.sender]>0,"locked balance is zero");
        uint256 amount = lockedBalances[msg.sender];

        lockedBalances[msg.sender] = 0;

        userFarmClaimedBalances[msg.sender] = userFarmClaimedBalances[msg.sender].add(lockedBalances[msg.sender]);

        IERC20(meltAddress).transfer(msg.sender,amount);
    }  

    /**
     * @dev Retrieve user's locked balance. 
     * @param account user's account.
     */ 
    function lockedBalanceOf(address account) public view returns (uint256) {
        return lockedBalances[account];
    }

    function releaseToken(address account,uint256 amount) external inited {
       
 	    // if(amount==0) {//remove to fixed release problem
		//    return;
		//}
		
        //msg.sender should be the farm contract,here is msg.sender
        IERC20(meltAddress).transferFrom(msg.sender,address(this),amount);
        //according day to cal idx
        uint256 idx = now.div(idxperiod);

        uint256 latest = userTxIdxs[account].length;
        if(latest == 0 || userTxIdxs[account][latest-1]!=idx){
            userTxIdxs[account].push(idx);
        }

        uint256 divAmount = amount.div(dispatchTimes);

        if( lockedAllRewards[account][idx].total==0) {
            lockedAllRewards[account][idx] = lockedReward(now,amount);
        } else {
            lockedAllRewards[account][idx].startTime = now;
            lockedAllRewards[account][idx].total = lockedAllRewards[account][idx].total.add(amount);
        }
        
        //index 0 to save the left token num
        lockedAllRewards[account][idx].alloc[0] = lockedAllRewards[account][idx].alloc[0].add(amount.sub(divAmount));
        uint256 i=2;
        //idx = 1, the reward give user immediately
        for(;i<dispatchTimes;i++){
            lockedAllRewards[account][idx].alloc[i] = lockedAllRewards[account][idx].alloc[i].add(divAmount);
        }
        lockedAllRewards[account][idx].alloc[i] = lockedAllRewards[account][idx].alloc[i].add(amount.sub(divAmount.mul(dispatchTimes-1)));

        lockedBalances[account] = lockedBalances[account].add(amount.sub(divAmount));
        IERC20(meltAddress).transfer(account,divAmount);

        userFarmClaimedBalances[account] = userFarmClaimedBalances[account].add(divAmount);

        //get current claimable balance for account
        uint256 claimable = getClaimAbleBalance(account);
        if(claimable>0) {
            claimpExpired(account);
        }

        emit Input(msg.sender,account,amount,divAmount);
    }



      /**
     * @dev user user claim expired reward
     */ 
    function claimpExpired(address account) internal inited {
        require(meltAddress !=address(0),"token should be set");
        
        uint256 txcnt = 0;
        uint256 idx = lockedIndexs[account].beginIdx;
        uint256 endIdx = userTxIdxs[account].length;
        uint256 totalRet = 0;

        uint256 pretxid = 0;
        for(;idx<endIdx && txcnt<txNum;idx++) {
           //i used for the user input  tx idx,too much i used before,no changed now
           uint256 i = userTxIdxs[account][idx];
           if(i!=pretxid){
                pretxid = i;
            } else {
                continue;
           }

           if (now >= lockedAllRewards[account][i].startTime + timeSpan) {
               if (lockedAllRewards[account][i].alloc[0] > 0) {
                    if (now >= lockedAllRewards[account][i].startTime + lockPeriod) {
                        totalRet = totalRet.add(lockedAllRewards[account][i].alloc[0]);
                        lockedAllRewards[account][i].alloc[0] = 0;
                        //updated last expired idx
                        lockedIndexs[account].beginIdx = idx;
                    } else {
                      
                        uint256 timeIdx = (now - lockedAllRewards[account][i].startTime).div(timeSpan) + 1;
                        uint256 j = 2;
                        uint256 subtotal = 0;
                        for(;j<timeIdx+1;j++) {
                            subtotal = subtotal.add(lockedAllRewards[account][i].alloc[j]);
                            lockedAllRewards[account][i].alloc[j] = 0;
                        }
                        
                        //updated left locked balance,possible?
                        if(subtotal<=lockedAllRewards[account][i].alloc[0]){
                            lockedAllRewards[account][i].alloc[0] = lockedAllRewards[account][i].alloc[0].sub(subtotal);
                        } else {
                            subtotal = lockedAllRewards[account][i].alloc[0];
                            lockedAllRewards[account][i].alloc[0] = 0;
                        }
                        
                        totalRet = totalRet.add(subtotal);
                    }
                    
                    txcnt = txcnt + 1;
               }
                
           } else {
               //the item after this one is pushed behind this,not needed to caculate
               break;
           }
        }
        
        lockedBalances[account] = lockedBalances[account].sub(totalRet);
        //transfer back to user
        IERC20(meltAddress).transfer(account,totalRet);

        userFarmClaimedBalances[account] = userFarmClaimedBalances[account].add(totalRet);

        emit Claim(account,totalRet,txcnt);
    }
    
      /**
     * @dev get user claimable balance
     */
    function getClaimAbleBalance(address account) public view returns (uint256) {
        require(meltAddress !=address(0),"melt token should be set");
        
        uint256 txcnt = 0;
        uint256 idx = lockedIndexs[account].beginIdx;
       //uint256 endIdx = lockedIndexs[_user].totalIdx;
        uint256 endIdx = userTxIdxs[account].length;
        uint256 totalRet = 0;
        uint256 pretxid = 0;

        for(;idx<endIdx && txcnt<txNum;idx++) {
            uint256 i = userTxIdxs[account][idx];
            if(i!=pretxid){
                pretxid = i;
            } else {
                continue;
            }
           //only count the rewards over at least one timeSpan
           if (now >= lockedAllRewards[account][i].startTime + timeSpan) {
               
               if (lockedAllRewards[account][i].alloc[0] > 0) {
                    if (now >= lockedAllRewards[account][i].startTime + lockPeriod) {
                        totalRet = totalRet.add(lockedAllRewards[account][i].alloc[0]);
                    } else {
                        uint256 timeIdx = (now - lockedAllRewards[account][i].startTime).div(timeSpan) + 1;
                        uint256 j = 2;
                        uint256 subtotal = 0;
                        for(;j<timeIdx+1;j++) {
                            subtotal = subtotal.add(lockedAllRewards[account][i].alloc[j]);
                        }
                        
                        //updated left locked balance,possible?
                        if(subtotal>lockedAllRewards[account][i].alloc[0]){
                            subtotal = lockedAllRewards[account][i].alloc[0];
                        }
                        
                        totalRet = totalRet.add(subtotal);
                    }
                    
                    txcnt = txcnt + 1;
               }
                
           } else {
               //the item after this one is pushed behind this,not needed to caculate
               break;
           }
        }
        
        return totalRet;
    }


    function getUserFarmClaimRecords(address account)
            public
            view
            returns
    (uint256,uint256[] memory,uint256[] memory) {
        uint256 idx = lockedIndexs[account].beginIdx;
        //uint256 endIdx = userTxIdxs[_user].length;
        uint256 len = (userTxIdxs[account].length - idx);
        uint256 retidx = 0;
        uint256 pretxid = 0;

        uint256[] memory retStArr = new uint256[]((dispatchTimes+1)*len);
        uint256[] memory retAllocArr = new uint256[]((dispatchTimes+1)*len);

        for(;idx<userTxIdxs[account].length;idx++) {
            uint256 i = userTxIdxs[account][idx];

            if(i!=pretxid){
                pretxid = i;
            } else {
                continue;
            }

            for(uint256 j=0;j<=dispatchTimes;j++) {
                retAllocArr[retidx*(dispatchTimes+1)+j] = lockedAllRewards[account][i].alloc[j];
                if(j==0) {
                    retStArr[retidx*(dispatchTimes+1)+j] = 0;
                } else {
                    retStArr[retidx*(dispatchTimes+1)+j] = lockedAllRewards[account][i].startTime.add(timeSpan*(j-1));
                }
            }
            retidx++;
        }

        return (dispatchTimes+1,retStArr,retAllocArr);
    }
    
}
