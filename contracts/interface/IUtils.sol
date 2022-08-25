// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

interface utilsInterafce {
    function findDay() external view returns(uint);
    function findEndDayTimeStamp(uint256 day) external view returns(uint256);
    function findMin (uint256 value) external view returns(uint256);
    function findBiggerPayBetter(uint256 inputPTP) external view returns(uint256);
    function findLongerPaysBetter(uint256 inputPTP, uint256 numOfDays) external view returns(uint256);
    function findBPDPercent (uint256 share,uint256 totalSharesOfBPD) external pure returns (uint256);
    function _calcAdoptionBonus(uint256 payout,uint256 claimedBtcAddrCount,uint256 claimedBTC,uint256 unClaimedBtc)external pure returns (uint256);
    function findDayDiff(uint256 endDayTimeStamp) external view returns(uint);
    function calcNewShareRate (uint256 fullAmount,uint256 stakeShares,uint256 stakeDays) external pure returns (uint256);
    function generateShare(uint256 inputPTP, uint256 LPB , uint256 BPB,uint256 shareRate) external pure returns(uint256);
    function findSillyWhalePenalty(uint256 amount) external pure returns (uint256);
    function findLatePenaltiy(uint256 dayPassed) external pure returns (uint256);
    function findSpeedBonus(uint256 day,uint256 share) external pure returns (uint256);
    function findReferalBonus(address user,uint256 share,address referer) external pure returns(uint256);
    function countShare (uint256 userSubmittedBNB, uint256 dayTotalBNB, uint256 availablePTP) external pure returns(uint256);
}
