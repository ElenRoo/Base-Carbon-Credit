// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IEcoCarbonCreditHub {
    function buyCarbonCredits(uint256 batchId, uint256 tonsToBuy) external payable;
    function listCarbonCredits(uint256 pricePerTonWei, uint256 totalTons, bytes32 certHash) external returns (uint256);
}
