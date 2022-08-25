// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./hashVerfication.sol";
contract MYNTIST is ERC20 {
    uint256 internal startDate = 1661234400;                            
    uint256 internal counterId = 0;            
    address internal originAddress = 0x6b26678F4f392B0E400CC419FA3E5161759ca380;
    uint256 internal originAmount = 0;  
    uint256 internal unClaimedBtc = 19000000 * 10 ** 8;
    uint256 internal claimedBTC = 0;
    uint256 internal constant shareRateDecimals = 10 ** 5;
    uint256 internal constant shareRateUintSize = 40;
    uint256 internal constant shareRateMax = (1 << shareRateUintSize) - 1;
    uint256 shareRate;
    uint256 internal claimedBtcAddrCount = 0;
    uint256 internal lastUpdatedDay;
    uint256 internal unClaimAATokens;
    address[] internal stakeAddress;

    SignatureVerification verfiyContract;

    // onlyOwner
    address internal owner;
    modifier onlyOwner {
      require(msg.sender == owner);
      _;
    }

    struct transferInfo {
        address to;
        address from; 
        uint256 amount;
    }

    struct freeStakeClaimInfo {
        string btcAddress;
        uint256 balanceAtMoment;
        uint256 dayFreeStake;
        uint256 claimedAmount;
        uint256 rawBtc;
    }

    struct stakeRecord {
       uint256 stakeShare;
       uint numOfDays;
       uint256 currentTime;
       bool claimed;
       uint256 id;
       uint256 startDay;
       uint256 endDay;
       uint256 endDayTimeStamp;
       bool isFreeStake;
       string stakeName;
       uint256 stakeAmount;
       uint256 sharePrice; 
       
    }   
    //Adoption Amplifier Struct
    struct RecordInfo {
        uint256 amount;
        uint256 time;
        bool claimed;
        address user;
        address refererAddress;
    }

    struct referalsRecord {
        address referdAddress;
        uint256 day;
        uint256 awardedMynt;
    }

    struct dailyData{
        uint256 dayPayout;
        uint256 stakeShareTotal;
        uint256 unclaimed;
        uint256 mintedTokens;
        uint256 stakedToken;
    }

    mapping (uint256 => mapping(address => RecordInfo)) public AARecords;
    mapping (address => referalsRecord[]) public referals;
    mapping (uint => uint256) public totalBNBSubmitted; 
    mapping (uint256 => address[]) public perDayAARecords;
    mapping (address => uint256) internal stakes;
    mapping (address => stakeRecord[]) public  stakeHolders;
    mapping (address => transferInfo[]) public transferRecords;
    mapping (address => freeStakeClaimInfo[]) public freeStakeClaimRecords;
    mapping (string  => bool) public btcAddressClaims;
    mapping (uint256 => uint256) public perDayPenalties;
    mapping (uint256 => uint256) public perDayUnclaimedBTC;
    mapping (uint256 => dailyData) public dailyDataUpdation;
    mapping (uint256 => uint256) public subtractedShares;
    // event unclaimedToken(uint256,uint256,uint256);
    // event Received(address, uint256);
    event CreateStake(uint256 id,uint256 stakeShares);
    // event EarlyPenalty(uint256 Penalty);
    // event claimStakeRewardEvent(uint256 amount,uint256 shares,uint256 totalDays, uint256 newShare,uint256 penalty);
    // event enterLobby(uint256,address);
    // event claimTokenAA(uint256,uint256,uint256);
    // event BtcClaim(uint256,uint256,uint256);
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    constructor() ERC20("MYNTIST", "MYNT")  {
        owner =  msg.sender;
        lastUpdatedDay = 0;
        shareRate = 1 * shareRateDecimals;
        verfiyContract = SignatureVerification(0x698d1355329FBB711b3cee811EDCed43c86c6234);
    }

    function withdraw() public onlyOwner {
     payable(msg.sender).transfer(payable(address(this)).balance);
    }

    function mintAmount(address user, uint256 amount) internal{
            uint256 currentDay = findDay();
            dailyData memory dailyRecord = dailyDataUpdation[currentDay];
            dailyRecord.mintedTokens = dailyRecord.mintedTokens + amount;
            dailyDataUpdation[currentDay] = dailyRecord;
            _mint(user,amount);
        
    }

    function findDay() internal view returns(uint) {
        uint day = block.timestamp - startDate;
        day = day / 1500;
        return day;
    }

    function updateDailyData(uint256 beginDay,uint256 endDay) internal{
       
        if(lastUpdatedDay == 0){
            beginDay = 0;
        }
        for(uint256 i = beginDay; i<= endDay; i++){
            uint256 iterator = i;
            if(iterator != 0){
                iterator = iterator - 1;
            }
            dailyData memory dailyRecord = dailyDataUpdation[iterator];
            uint256 dailyLimit =getDailyShare(iterator);
            uint256 sharesToSubtract = subtractedShares[i];
            uint256 totalShares = dailyRecord.stakeShareTotal - sharesToSubtract;
            if(i >= 2){
                uint256 unClaimAmount = unclaimedRecord(i);
                unClaimAATokens = unClaimAATokens + unClaimAmount;
              }
            dailyData memory myRecord = dailyData({dayPayout:dailyLimit,stakeShareTotal:totalShares,unclaimed:dailyRecord.unclaimed,
            mintedTokens:dailyRecord.mintedTokens,stakedToken:dailyRecord.stakedToken});
            dailyDataUpdation[i] = myRecord;
        }
        lastUpdatedDay = endDay;
    }

    function getDailyData(uint256 day) public view returns (dailyData memory) {
        if(lastUpdatedDay < day){
            return dailyDataUpdation[lastUpdatedDay];
        }
        else{
            return dailyDataUpdation[day];
        }

    } 

    function isStakeholder(address _address) public view returns(bool, uint256) { 

        for (uint256 s = 0; s < stakeAddress.length; s += 1){
            if (_address == stakeAddress[s]) return (true, s);
        }
        return (false, 0);
    }

    // function findEndDayTimeStamp(uint256 day) internal view returns(uint256){
    //    uint256 futureDays = day * 3600;
    //    futureDays = block.timestamp + futureDays;
    //    return futureDays;
    // }
 
    // function findMin (uint256 value) internal pure returns(uint256){
    //     uint256 maxValueBPB = 150000000 * 10 ** 8;
    //     uint256 minValue;
    //     if(value <=  maxValueBPB){
    //         minValue = value;
    //     }
    //     else{
    //         minValue = maxValueBPB; 
    //     }
    //    return minValue; 
    // }

    function findBiggerPayBetter(uint256 inputMynt) internal pure returns(uint256){
        uint256 divValueBPB = 1500000000 * 10 ** 8;
        // uint256 minValue = findMin(inputMynt);
        uint256 maxValueBPB = 150000000 * 10 ** 8;
        uint256 minValue;
        if(inputMynt <=  maxValueBPB){
            minValue = inputMynt;
        }
        else{
            minValue = maxValueBPB; 
        }
        uint256 BPB = inputMynt * minValue;
        BPB = BPB / divValueBPB; 
        return BPB;
    }  

    function findLongerPaysBetter(uint256 inputMynt, uint256 numOfDays) internal pure returns(uint256){
        if(numOfDays > 3641){
            numOfDays = 3641;
        }
        uint256 daysToUse = numOfDays - 1; 
        uint256 LPB = inputMynt * daysToUse;
        LPB = LPB / 1820;
        return LPB;
    } 

    function generateShare(uint256 inputMynt, uint256 LPB , uint256 BPB) internal view returns(uint256){
            uint256 share = LPB + BPB;
            share = share + inputMynt;
            share = share / shareRate;
            share = share * shareRateDecimals;
            return share;  
    }

    function createStake(uint256 _stake,uint day,string memory stakeName) external {
        uint256 balance = balanceOf(msg.sender);
        require(balance >= _stake,'Not enough amount for staking');
        (bool _isStakeholder, ) = isStakeholder(msg.sender);
        if(! _isStakeholder) {stakeAddress.push(msg.sender);}
         _burn(msg.sender,_stake);
        uint256 id = counterId++;
        uint256 currentDay = findDay();
        uint256 endDay = currentDay + day;
        uint256 endDayTimeStamp = day * 1500;
        endDayTimeStamp = block.timestamp + endDayTimeStamp;
        uint256 BPB = findBiggerPayBetter(_stake);
        originAmount = originAmount + BPB;
        uint256 LPB = findLongerPaysBetter(_stake,day);
        originAmount = originAmount + LPB;
        uint256 share = generateShare(_stake,LPB,BPB);
        require(share >= 1,'Share too low');
        // bool updateRequire = checkDataUpdationRequired();
        if(currentDay > lastUpdatedDay){
            uint256 startDay = lastUpdatedDay + 1;
            updateDailyData(startDay,currentDay);
        }
        subtractedShares[endDay] = subtractedShares[endDay] + share;
        stakeRecord memory myRecord = stakeRecord({id:id,stakeShare:share,stakeName:stakeName, numOfDays:day, currentTime:block.timestamp,claimed:false,startDay:currentDay,endDay:endDay,
        endDayTimeStamp:endDayTimeStamp,isFreeStake:false,stakeAmount:_stake,sharePrice:shareRate});
        stakeHolders[msg.sender].push(myRecord);
        dailyData memory dailyRecord = dailyDataUpdation[currentDay];
        dailyRecord.stakeShareTotal = dailyRecord.stakeShareTotal + share;
        dailyRecord.dayPayout = getDailyShare(currentDay);
        dailyRecord.unclaimed = unClaimedBtc;
        dailyRecord.mintedTokens = dailyRecord.mintedTokens - _stake;
        dailyRecord.stakedToken = dailyRecord.stakedToken + _stake;
        dailyDataUpdation[currentDay] = dailyRecord;
        emit CreateStake(id,share);
    }

    function transferStake(uint256 id,address transferTo) external {
        uint256 currentDay = findDay();
        // bool updateRequire = checkDataUpdationRequired();
        if(currentDay > lastUpdatedDay){
            uint256 startDay = lastUpdatedDay + 1;
            updateDailyData(startDay,currentDay);
        }
     stakeRecord[] memory myRecord = stakeHolders[msg.sender];
     for(uint i=0; i<myRecord.length; i++){
        if(myRecord[i].id == id){
        stakeHolders[transferTo].push(stakeHolders[msg.sender][i]); 
        delete(stakeHolders[msg.sender][i]);
        }
     }
    }

    function getDailyShare (uint256 day) public view returns(uint256 dailyRewardOfDay){
        uint256 penalties = perDayPenalties[day];
        dailyData memory data = getDailyData(day);
        uint256 allocSupply = data.mintedTokens + data.stakedToken;
        dailyRewardOfDay = allocSupply * 10000;
        dailyRewardOfDay = dailyRewardOfDay / 100448995;
        dailyRewardOfDay = dailyRewardOfDay + penalties;
        return  dailyRewardOfDay;
    }

    function findBPDPercent (uint256 share,uint256 totalSharesOfBPD) internal pure returns (uint256){
        uint256 totalShares = totalSharesOfBPD;
        uint256 sharePercent = share * 10 ** 4;
        sharePercent = sharePercent / totalShares;
        sharePercent = sharePercent * 10 ** 2;
        return sharePercent;   
    }

    function findStakeSharePercent (uint256 share,uint256 day) internal view returns (uint256){
        dailyData memory data = dailyDataUpdation[day];
        uint256 sharePercent = share * 10 ** 4;
        sharePercent = sharePercent / data.stakeShareTotal;
        sharePercent = sharePercent * 10 ** 2;
        return sharePercent;   
    }

    function _calcAdoptionBonus(uint256 payout)internal view returns (uint256){
        uint256 claimableBtcAddrCount = 27997742;
        uint256 bonus = 0;
        uint256 viral = payout * claimedBtcAddrCount;
        viral = viral / claimableBtcAddrCount;
        uint256 crit = payout * claimedBTC;
        crit = crit / unClaimedBtc;
        bonus = viral + crit;
        return bonus; 
    }

    function getAllDayReward(uint256 beginDay,uint256 endDay,uint256 stakeShare) internal view returns (uint256 ){
         uint256 totalIntrestAmount = 0; 
        for (uint256 day = beginDay; day < endDay; day++) {
            dailyData memory data = dailyDataUpdation[day];
            uint256 dayShare = getDailyShare(day);
            uint256 currDayAmount = dayShare * stakeShare;
            currDayAmount = currDayAmount / data.stakeShareTotal;
            totalIntrestAmount = totalIntrestAmount + currDayAmount; 
            }
          if (beginDay <= 351 && endDay > 351) {
              dailyData memory data = dailyDataUpdation[350];  
              uint256 sharePercentOfBPD = findBPDPercent(stakeShare,data.stakeShareTotal);
              uint256 bigPayDayAmount = getBigPayDay();
              bigPayDayAmount = bigPayDayAmount + unClaimAATokens;
              uint256 bigPaySlice = bigPayDayAmount * sharePercentOfBPD;
              bigPaySlice = bigPaySlice/ 100 * 10 ** 4;
              totalIntrestAmount = bigPaySlice + _calcAdoptionBonus(bigPaySlice);
            }
        return totalIntrestAmount;
    }

    function findEstimatedIntrest (uint256 stakeShare,uint256 startDay) internal view returns (uint256) {
            uint256 day = findDay();
            uint256 sharePercent = findStakeSharePercent(stakeShare,startDay);
            uint256 dailyEstReward = getDailyShare(day);
            uint256 perDayProfit = dailyEstReward * sharePercent;
            perDayProfit = perDayProfit / 100 * 10 ** 4;
            return perDayProfit;

    }

    function getDayRewardForPenalty(uint256 beginDay,uint256 stakeShare, uint256 dayData) internal view returns (uint256){
         uint256 totalIntrestAmount = 0;
          for (uint256 day = beginDay; day < beginDay + dayData; day++) {
            uint256 dayShare = getDailyShare(day);
            totalIntrestAmount = dayShare * stakeShare;
            dailyData memory data = dailyDataUpdation[day];
            totalIntrestAmount = totalIntrestAmount / data.stakeShareTotal;
            }
        return totalIntrestAmount;
    }

    function earlyPenaltyForShort(stakeRecord memory stakeData,uint256 totalIntrestAmount) internal view returns(uint256){
            uint256 emergencyDayEnd = block.timestamp - stakeData.currentTime;
            emergencyDayEnd = emergencyDayEnd / 1500;
            uint256 penalty;
            if(emergencyDayEnd == 0){
                uint256 estimatedAmount = findEstimatedIntrest(stakeData.stakeShare,stakeData.startDay);
                estimatedAmount = estimatedAmount * 90;
                penalty = estimatedAmount;
            }

            if(emergencyDayEnd < 90 && emergencyDayEnd !=0){
                penalty = totalIntrestAmount * 90;
                penalty = penalty / emergencyDayEnd;
               
            }

            if(emergencyDayEnd == 90){
                penalty = totalIntrestAmount;
                
            }

            if(emergencyDayEnd > 90){
                uint256 rewardTo90Days = getDayRewardForPenalty(stakeData.startDay,stakeData.stakeShare,89);
                 penalty = totalIntrestAmount - rewardTo90Days;
            }
            return penalty;
    }

    function earlyPenaltyForLong(stakeRecord memory stakeData,uint256 totalIntrestAmount) internal view returns(uint256){
            uint256 emergencyDayEnd = block.timestamp - stakeData.currentTime;
            emergencyDayEnd = emergencyDayEnd / 1500;
            uint256 endDay = stakeData.numOfDays;
            uint256 halfOfStakeDays = endDay / 2;
            uint256 penalty ;
            if(emergencyDayEnd == 0){
                uint256 estimatedAmount = findEstimatedIntrest(stakeData.stakeShare,stakeData.startDay);
                estimatedAmount = estimatedAmount * halfOfStakeDays;
                penalty = estimatedAmount;
            }

            if(emergencyDayEnd < halfOfStakeDays && emergencyDayEnd != 0){
                penalty = totalIntrestAmount * halfOfStakeDays;
                penalty = penalty / emergencyDayEnd;
            }

            if(emergencyDayEnd == halfOfStakeDays){
                penalty = totalIntrestAmount;
                
            }

            if(emergencyDayEnd > halfOfStakeDays){
                uint256 rewardToHalfDays = getDayRewardForPenalty(stakeData.startDay,stakeData.stakeShare,halfOfStakeDays);
                penalty = totalIntrestAmount - rewardToHalfDays;   
            }
            return penalty;
    }

    function latePenalties (stakeRecord memory stakeData,uint256 totalAmountReturned) internal  returns(uint256){
            uint256 dayAfterEnd = block.timestamp - stakeData.endDayTimeStamp;
            dayAfterEnd = dayAfterEnd / 1500;
            if(dayAfterEnd > 14){
            uint256 transferAmount = totalAmountReturned;
            uint256 perDayDeduction = 143 ;
            uint256 penalty = transferAmount * perDayDeduction;
            penalty = penalty / 1000; 
            penalty = penalty / 100;
            uint256 totalPenalty = dayAfterEnd * penalty;
            uint256 halfOfPenalty = totalPenalty / 2;
            uint256 actualAmount = 0;
            uint256 day = findDay();
             day = day + 1;
            if(totalPenalty < totalAmountReturned){

             perDayPenalties[day] = perDayPenalties[day] + halfOfPenalty;
             originAmount = originAmount + halfOfPenalty;
             actualAmount = totalAmountReturned - totalPenalty;
            }
            else{
             uint256 halfAmount = actualAmount / 2;
             perDayPenalties[day] = perDayPenalties[day] + halfAmount;
             originAmount = originAmount + halfAmount; 
            }
            return actualAmount;
            }
            else{
            return totalAmountReturned;
            }
    } 

    function settleStakes (address _sender,uint256 id) internal  {
        stakeRecord[] memory myRecord = stakeHolders[_sender];
        for(uint i=0; i<myRecord.length; i++){
            if(myRecord[i].id == id){
                myRecord[i].claimed = true;
                stakeHolders[_sender][i] = myRecord[i];
            }
        }
    }

    function calcNewShareRate (uint256 fullAmount,uint256 stakeShares,uint256 stakeDays) internal view returns (uint256){
        uint256 BPB = findBiggerPayBetter(fullAmount);
        uint256 LPB = findLongerPaysBetter(fullAmount,stakeDays);
        uint256 newShareRate = fullAmount + BPB + LPB;
        newShareRate = newShareRate * shareRateDecimals;
        newShareRate = newShareRate / stakeShares;
        if (newShareRate > shareRateMax) {
                newShareRate = shareRateMax;
            }
        if(newShareRate > shareRate * 4){
            newShareRate = shareRate * 4;
        }
        return newShareRate ;
    }

    function claimStakeReward (uint id) external  {
        (bool _isStakeholder, ) = isStakeholder(msg.sender);
        require(_isStakeholder,'Not SH');

        stakeRecord[] memory myRecord2 = stakeHolders[msg.sender];
        stakeRecord memory stakeData;
        uint256 currDay = findDay();
        uint256 penaltyDay = currDay + 1;
        uint256 dayToFindBonus;
        uint256 amountToNewShareRate;
        // uint256 cutPenalty;
        // bool updateRequire = checkDataUpdationRequired();
        if(currDay > lastUpdatedDay){
            uint256 startDay = lastUpdatedDay + 1;
            updateDailyData(startDay,currDay);
        }
        for(uint i=0; i<myRecord2.length; i++){
            if(myRecord2[i].id == id){ 
                stakeData = myRecord2[i];
            }
        }
        if(stakeData.endDay > currDay){
            dayToFindBonus = currDay;
        }
        else{
            dayToFindBonus = stakeData.endDay;
        }
        uint256 totalIntrestAmount = getAllDayReward(stakeData.startDay,dayToFindBonus,stakeData.stakeShare);
        if(block.timestamp < stakeData.endDayTimeStamp){
           require(stakeData.isFreeStake != true,"Free Stake can't be claim early");
            uint256 penalty;
            if(stakeData.numOfDays < 180){
                 penalty = earlyPenaltyForShort(stakeData,totalIntrestAmount);
                //  emit EarlyPenalty(penalty);
                //  cutPenalty = penalty; 
             }
            
            if(stakeData.numOfDays >= 180){
                 penalty = earlyPenaltyForLong(stakeData,totalIntrestAmount); 
                //  cutPenalty = penalty;
            } 

                uint256 halfOfPenalty = penalty / 2;
                uint256 compeleteAmount = stakeData.stakeAmount + totalIntrestAmount;
                uint256 amountToMint = 0;
                if(penalty < compeleteAmount){ 
                    perDayPenalties[penaltyDay] = perDayPenalties[penaltyDay] + halfOfPenalty;
                    originAmount = originAmount + halfOfPenalty; 
                    amountToMint = compeleteAmount - penalty;
                }
                else{
                    uint256 halfAmount = compeleteAmount / 2;
                    perDayPenalties[penaltyDay] = perDayPenalties[penaltyDay] + halfAmount;
                    originAmount = originAmount + halfAmount; 
                }
                dailyData memory data = dailyDataUpdation[currDay];
                data.stakeShareTotal = data.stakeShareTotal - stakeData.stakeShare;
                dailyDataUpdation[currDay] = data;
                amountToNewShareRate = amountToMint;
                mintAmount(msg.sender,amountToMint);
        }

        if(block.timestamp >= stakeData.endDayTimeStamp){
         uint256 totalAmount = stakeData.stakeAmount + totalIntrestAmount;
         uint256 amounToMinted = latePenalties(stakeData,totalAmount);
         amountToNewShareRate = amounToMinted;
         mintAmount(msg.sender,amounToMinted);
        }
        settleStakes(msg.sender,id);
        uint256 newShare = calcNewShareRate(amountToNewShareRate, stakeData.stakeShare, stakeData.numOfDays);
        if(newShare > shareRate){
            shareRate = newShare;
        }
        dailyData memory dailyRecord = dailyDataUpdation[currDay];
        dailyRecord.stakedToken = dailyRecord.stakedToken - stakeData.stakeAmount;
        dailyDataUpdation[currDay] = dailyRecord;
    //    emit claimStakeRewardEvent(amountToNewShareRate,stakeData.stakeShare,stakeData.numOfDays, newShare,cutPenalty);
    }

    function getStakeRecords() external view returns (stakeRecord[] memory stakeHolder) {
        
        return stakeHolders[msg.sender];
    }

    function getStakeSharePercent(address user, uint256 stakeId, uint256 dayToFind) external view returns(uint256){
        stakeRecord[] memory myRecord = stakeHolders[user];
        dailyData memory data = dailyDataUpdation[dayToFind];
        uint256 sharePercent;
        for(uint i=0; i<myRecord.length; i++){
            if(myRecord[i].id == stakeId){
            sharePercent = myRecord[i].stakeShare * 10 ** 4;
            sharePercent = sharePercent / data.stakeShareTotal;
            }
        }
        return  sharePercent;
    }
    //Free Stake functionality

    function createFreeStake(uint256 autoStakeDays,string memory btcAddress,uint balance,address refererAddress,bytes32[] calldata proof,bytes32 messageHash,
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        uint8 v,
        bytes32 r,
        bytes32 s) external {
        // require(block.timestamp < startDate + 31536000,'Free stakes available just 1 year');
        // require(block.timestamp >= startDate ,'Free stakes not started yet');
        require(balance > 0, 'You need to have more than 0 Btc in your wallet');
        bool verfication = verfiyContract.btcAddressClaim(balance, proof, messageHash, pubKeyX, pubKeyY, v, r, s);
        require(verfication,"not verfied");
        // bool isClaimable = btcAddressClaims[btcAddress];

        // require(!isClaimable,"Already claimed");
        uint day = findDay();
        uint256 stakeDays = autoStakeDays;
        uint userBtcBalance = balance;
        string memory userBtcAddress = btcAddress;
        address userReferer = refererAddress;
        
        // bool updateRequire = checkDataUpdationRequired();
        if(day > lastUpdatedDay){
            uint256 startDay = lastUpdatedDay + 1;
            updateDailyData(startDay,day);
        }

        distributeFreeStake(msg.sender,userBtcAddress,day,userBtcBalance, userReferer,stakeDays); 
        unClaimedBtc = unClaimedBtc - userBtcBalance;
        perDayUnclaimedBTC[day] = perDayUnclaimedBTC[day] + userBtcBalance;
        claimedBTC = claimedBTC + userBtcBalance;
        btcAddressClaims[userBtcAddress] = true;
        claimedBtcAddrCount ++ ;  
        dailyData memory dailyRecord = dailyDataUpdation[day];
        dailyRecord.unclaimed = unClaimedBtc;
       
        dailyRecord.dayPayout = getDailyShare(day);

        dailyDataUpdation[day] = dailyRecord;   
    }

    function findSillyWhalePenalty(uint256 amount) internal pure returns (uint256){
        if(amount < 1000e8){
            return amount;
        }
        else if(amount >= 1000e8 && amount < 10000e8){  
            uint256 penaltyPercent = amount - 1000e8;
            penaltyPercent = penaltyPercent * 25 * 10 ** 2;
            penaltyPercent = penaltyPercent / 9000e8; 
            penaltyPercent = penaltyPercent + 50 * 10 ** 2; 
            uint256 deductedAmount = amount * penaltyPercent; 
            deductedAmount = deductedAmount / 10 ** 4;          
            uint256 adjustedBtc = amount - deductedAmount;  
            return adjustedBtc;   
        }
        else { 
            uint256 adjustedBtc = amount * 25;
            adjustedBtc = adjustedBtc / 10 ** 2;
            return adjustedBtc;  
        }
    }

    function findLatePenaltiy(uint256 dayPassed) internal pure returns (uint256){
        uint256 totalDays = 350;
        uint256 latePenalty = totalDays - dayPassed;
        latePenalty = latePenalty * 10 ** 4;
        latePenalty = latePenalty / 350;
        return latePenalty; 
    }

    function findSpeedBonus(uint256 day,uint256 share) internal pure returns (uint256){
      uint256 speedBonus = 0;
      uint256 initialAmount = share;
      uint256 percentValue = initialAmount * 20;
      uint256 perDayValue = percentValue / 350;  
      uint256 deductedAmount = perDayValue * day;      
      speedBonus = percentValue - deductedAmount;
      return speedBonus;

    }

    function findReferalBonus(address user,uint256 share,address referer) internal returns(uint256) { 
       uint256 fixedAmount = share;
       uint256 sumUpAmount = 0;
      if(referer != address(0)){
       if(referer != user){
         
        // if referer is not user it self
        uint256 referdBonus = fixedAmount * 10;
        referdBonus = referdBonus / 100;
        sumUpAmount = sumUpAmount + referdBonus;
       }
       else{
        // if a user referd it self  
        uint256 referdBonus = fixedAmount * 20;
        referdBonus = referdBonus / 100;
        sumUpAmount = sumUpAmount + referdBonus;
        createReferalRecords(referer,user,sumUpAmount);
        }
       }
       return sumUpAmount;
    }

    function createReferalRecords(address refererAddress, address referdAddress,uint256 awardedMynt) internal {
        uint day = findDay();
        referalsRecord memory myRecord = referalsRecord({referdAddress:referdAddress,day:day,awardedMynt:awardedMynt});
        referals[refererAddress].push(myRecord);
    }

    function createFreeStakeClaimRecord(address userAddress,string memory btcAddress,uint256 day,uint256 balance,uint256 claimedAmount) internal {

     freeStakeClaimInfo memory myRecord = freeStakeClaimInfo({btcAddress:btcAddress,balanceAtMoment:balance,dayFreeStake:day,claimedAmount:claimedAmount,rawBtc:unClaimedBtc});
     freeStakeClaimRecords[userAddress].push(myRecord);
    }

    function freeStaking(uint256 stakeAmount,address userAddress,uint256 autoStakeDays) internal  {
        uint256 id = counterId++;
        uint256 startDay = findDay();
        uint256 endDay = startDay + autoStakeDays;   
        uint256 endDayTimeStamp = endDay * 1500;
        endDayTimeStamp = block.timestamp + endDayTimeStamp;
        uint256 share = generateShare(stakeAmount,0,0);
        subtractedShares[endDay] = subtractedShares[endDay] + share;
        stakeRecord memory myRecord = stakeRecord({id:id,stakeShare:share, stakeName:'', numOfDays:365,
         currentTime:block.timestamp,claimed:false,startDay:startDay,endDay:endDay,
        endDayTimeStamp:endDayTimeStamp,isFreeStake:true,stakeAmount:stakeAmount,sharePrice:shareRate});
        stakeHolders[userAddress].push(myRecord); 
        dailyData memory dailyRecord = dailyDataUpdation[startDay];
        dailyRecord.stakeShareTotal = dailyRecord.stakeShareTotal + share;
        dailyRecord.stakedToken = dailyRecord.stakedToken + stakeAmount;
        dailyDataUpdation[startDay] = dailyRecord;
        (bool _isStakeholder, ) = isStakeholder(userAddress);
        if(! _isStakeholder) {stakeAddress.push(msg.sender);}
        
    }

    function distributeFreeStake(address userAddress,string memory btcAddress,uint256 day,uint256 balance,address refererAddress,uint256 autoStakeDays) internal {
            uint256 sillyWhaleValue = findSillyWhalePenalty(balance);
            uint share = sillyWhaleValue * 10 ** 8;
            share = share / 10 ** 4;
            uint256 actualAmount = share;  
            uint256 latePenalty = findLatePenaltiy(day);
            actualAmount = actualAmount * latePenalty;
            //Late Penalty return amount in 4 decimal to avoid decimal issue,
            // we didvide with 10 ** 4 to find actual amount 
            actualAmount = actualAmount / 10 ** 4;
            //Speed Bonus
            
            uint256 userSpeedBonus = findSpeedBonus(day,actualAmount);
            userSpeedBonus = userSpeedBonus / 100;
            actualAmount = actualAmount + userSpeedBonus;
            originAmount = originAmount + actualAmount;

            uint256 refBonus = 0;
           //Referal Mints 
            if(refererAddress != userAddress && refererAddress != address(0)){
                uint256 amount = actualAmount;
                uint256 referingBonus = amount * 20;
                referingBonus = referingBonus / 100;
                originAmount = originAmount + referingBonus;
                mintAmount(refererAddress,referingBonus);
                createReferalRecords(refererAddress,userAddress,referingBonus);
           }
        
         //Referal Bonus
            if(refererAddress != address(0)){
            refBonus = findReferalBonus(userAddress,actualAmount,refererAddress);
            actualAmount = actualAmount + refBonus;
            originAmount = originAmount + refBonus;
            // createReferalRecords(refererAddress,userAddress,refBonus);
          }
         uint256 mintedValue = actualAmount * 10; 
         mintedValue = mintedValue / 100;
         mintAmount(userAddress,mintedValue); 
         createFreeStakeClaimRecord(userAddress,btcAddress,day,balance,mintedValue);

         uint256 stakeAmount = actualAmount * 90;
         stakeAmount = stakeAmount / 100; 
         freeStaking(stakeAmount,userAddress,autoStakeDays);
        //  emit BtcClaim(originAmount, sillyWhaleValue, actualAmount);

    }

    function getFreeStakeClaimRecord() external view returns (freeStakeClaimInfo[] memory claimRecords){
       return freeStakeClaimRecords[msg.sender];
    } 

    function extendStakeLength(uint256 totalDays, uint256 id) external {  
        uint256 currentDay = findDay();
        // bool updateRequire = checkDataUpdationRequired();
        if(currentDay > lastUpdatedDay){
            uint256 startDay = lastUpdatedDay + 1;
            updateDailyData(startDay,currentDay);
        }
        stakeRecord[] memory myRecord = stakeHolders[msg.sender];
        for(uint i=0; i<myRecord.length; i++){
            if(myRecord[i].id == id){
                if(myRecord[i].isFreeStake){
                    if(totalDays >= 365){
                        require(myRecord[i].startDay + totalDays > myRecord[i].numOfDays , 'condition should not be meet');
                        myRecord[i].numOfDays = myRecord[i].numOfDays + totalDays;
                        myRecord[i].endDay = myRecord[i].startDay + totalDays;
                        uint256 endDayTimeStamp = myRecord[i].endDay * 1500;
                        endDayTimeStamp = block.timestamp + endDayTimeStamp;
                        myRecord[i].endDayTimeStamp = endDayTimeStamp;
                    }
                }
             stakeHolders[msg.sender][i] = myRecord[i];
            }
        }
    }

    // function findAddress(uint256 day, address sender)internal view returns(bool){
    //     address addressValue = AARecords[day][sender].user;
    //     if(addressValue == address(0)){
    //         return false;
    //     }
    //     else{
    //        return true;
    //     }
    // }

    function enterAALobby (address refererAddress) external payable {
        require(msg.value > 0, '0 Balance');
        uint day = findDay();
        // bool updateRequire = checkDataUpdationRequired();
        if(day > lastUpdatedDay){
            uint256 startDay = lastUpdatedDay + 1;
            updateDailyData(startDay,day);
        }
        RecordInfo memory myRecord = RecordInfo({amount: msg.value, time: block.timestamp, claimed: false, user:msg.sender,refererAddress:refererAddress});
        // bool check = findAddress(day,msg.sender);
        bool check;
        address addressValue = AARecords[day][msg.sender].user;
        if(addressValue == address(0)){
            check = false;
        }
        else{
           check = true;
        }
        if(check == false){
            AARecords[day][msg.sender] = myRecord;
            perDayAARecords[day].push(msg.sender);
        }  
        else{
            RecordInfo memory record = AARecords[day][msg.sender];
            record.amount = record.amount + msg.value;
            AARecords[day][msg.sender] = record;
        }
      
        totalBNBSubmitted[day] = totalBNBSubmitted[day] + msg.value;
        // emit enterLobby(msg.value,msg.sender);
    }

    function getTotalBNB (uint day) public view returns (uint256){
        
       return totalBNBSubmitted[day];
    }

    function getAvailableMynt (uint day) public view returns (uint256 daySupply){
        uint256 myntAvailabel = 0;
       
        uint256 firstDayAvailabilty = 1000000000 * 10 ** 8; 
        if(day == 0){
            myntAvailabel = firstDayAvailabilty;
        }
        else{
            uint256 othersDayAvailability = 19000000 * 10 ** 8;
            uint256 totalUnclaimedToken = 0;
            for(uint256 i = 0; i < day; i++){
                totalUnclaimedToken= totalUnclaimedToken + perDayUnclaimedBTC[i];
            }
            
            othersDayAvailability = othersDayAvailability - totalUnclaimedToken;
            //as per rules we have to multiply it with 10^8 than divided with 10 ^ 4 but as we can make it multiply 
            //with 10 ^ 4
            othersDayAvailability = othersDayAvailability * 10 ** 4;
            myntAvailabel = othersDayAvailability / 350;
        }
        daySupply = myntAvailabel;
       return daySupply;
    }

    function getTransactionRecords(uint day,address user) public view returns (RecordInfo memory record) {   
            return AARecords[day][user];
    }

    function countShare (uint256 userSubmittedBNB, uint256 dayTotalBNB, uint256 availableMynt) internal pure returns  (uint256) {
        uint256 share = 0;
        //to avoid decimal issues we add 10 ** 5
        share = userSubmittedBNB * 10 ** 5 / dayTotalBNB;
        share = share * availableMynt;
        return share / 10 ** 5;
    }

    function claimAATokens () external {
        uint256 presentDay = findDay();
        require(presentDay > 0,'not now');
        // bool updateRequire = checkDataUpdationRequired();
        if(presentDay > lastUpdatedDay){
            uint256 startDay = lastUpdatedDay + 1;
            updateDailyData(startDay,presentDay);
        }
        uint256 prevDay = presentDay - 1;
        uint256 dayTotalBNB = getTotalBNB(prevDay);
        uint256 availableMynt = getAvailableMynt(prevDay);
        RecordInfo memory record = getTransactionRecords(prevDay,msg.sender);
        if(record.user != address(0) && record.claimed == false){
           uint256 userSubmittedBNB = record.amount;
           uint256 userShare = 0;
           uint256 referalBonus = 0;
           userShare = countShare(userSubmittedBNB,dayTotalBNB,availableMynt);
            address userReferer = record.refererAddress;
            if(userReferer != msg.sender && userReferer !=address(0)){
             uint256 amount = userShare;
             uint256 referingBonus = amount * 20;
             referingBonus = referingBonus / 100;
             originAmount = originAmount + referingBonus;
             mintAmount(userReferer,referingBonus);
             createReferalRecords(userReferer,msg.sender,referingBonus);
             }
            referalBonus =  findReferalBonus(msg.sender,userShare,userReferer);  
             userShare = userShare + referalBonus;
             originAmount = originAmount + referalBonus;
             mintAmount(msg.sender,userShare);
             RecordInfo memory myRecord = AARecords[prevDay][msg.sender];
                 myRecord.claimed = true;
                 AARecords[prevDay][msg.sender] = myRecord;
            //  settleSubmission(prevDay,msg.sender);
            //  if(userReferer != address(0)){
            //   createReferalRecords(userReferer,msg.sender,referalBonus);
            //  }
            // emit claimTokenAA(userShare,dayTotalBNB,record.amount);
        }
    }

    function getReferalRecords(address refererAddress) external view returns (referalsRecord[] memory referal) {
        
        return referals[refererAddress];
    }

    function transferMynt(address recipientAddress, uint256 _amount) external{
        uint256 currentDay = findDay();
        _transfer(msg.sender,recipientAddress,_amount);
        transferInfo memory myRecord = transferInfo({amount: _amount,to:recipientAddress, from: msg.sender});
        if(currentDay > lastUpdatedDay){
            uint256 startDay = lastUpdatedDay + 1;
            updateDailyData(startDay,currentDay);
        }
        transferRecords[msg.sender].push(myRecord);
    }

    function getTransferRecords( address _address ) external view returns (transferInfo[] memory transferRecord) {
        return transferRecords[_address];
    } 

    function getBigPayDay() internal view returns (uint256){
        uint256 totalAmount = 0;
        for(uint256 j = 0 ; j<=350; j++){
            dailyData memory data = dailyDataUpdation[j];
            uint256 btc = data.unclaimed / 10 ** 8;
            uint256 bigPayDayAmount = btc * 2857;
            //it should be divieded with 10 ** 6 but we have to convert it in mynt so we div it 10 ** 2
            bigPayDayAmount = bigPayDayAmount / 10 ** 2;
            totalAmount = totalAmount + bigPayDayAmount;
        }
        return totalAmount ;
    }
    
    function getShareRate() external view returns (uint256){
        return shareRate;
    }

    function unclaimedRecord(uint256 presentDay) internal view returns (uint256 unclaimedAAToken) {
        uint256 prevDay = presentDay - 2;
        uint256 dayTotalBNB = getTotalBNB(prevDay);
        uint256 availableMynt = getAvailableMynt(prevDay);
        address[] memory allUserAddresses = perDayAARecords[prevDay];
        if(allUserAddresses.length > 0){
            for(uint i = 0; i < allUserAddresses.length; i++){
                uint256 userSubmittedBNB = 0;
                uint256 userShare = 0;
                RecordInfo memory record = getTransactionRecords(prevDay,allUserAddresses[i]);
                if(record.claimed == false){
                    userSubmittedBNB = record.amount;
                    userShare = countShare(userSubmittedBNB,dayTotalBNB,availableMynt);
                    unclaimedAAToken = unclaimedAAToken + userShare;
                }
            
            } 
        }  
        else{
         unclaimedAAToken = unclaimedAAToken + availableMynt;
        }
        return unclaimedAAToken;
    }
}