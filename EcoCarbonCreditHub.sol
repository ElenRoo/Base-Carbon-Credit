// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

contract EcoCarbonCreditHub {
    struct CreditBatch {
        address payable projectOwner;
        uint256 pricePerTonWei;
        uint256 availableTons;
        bool isActive;
        bytes32 certificationHash;
    }

    address payable public immutable hubAdmin;
    string public hubDescriptor;
    uint256 public platformFeeBps; // 250 = 2.5%
    uint256 public batchCounter;
    uint256 public accumulatedFees;
    bool public isHubHalted;

    mapping(address => bool) public certifiedProjects;
    mapping(uint256 => CreditBatch) public creditBatches;
    mapping(address => uint256) public retiredCreditsByCompany;

    event ProjectCertified(address indexed projectOwner);
    event CreditsPurchased(uint256 indexed batchId, address indexed buyer, uint256 tons, uint256 price);
    event ListingCanceled(uint256 indexed batchId);
    event TreasuryDeposited(address indexed funder, uint256 amount);
    event ReservesEmptied(address indexed admin, uint256 amount);
    event FeesGathered(address indexed admin, uint256 amount);
    event HubHaltToggled(bool isHalted);
    event CreditsListed(uint256 indexed batchId, address indexed projectOwner, uint256 price, uint256 tons);
    event CreditsRetired(address indexed company, uint256 tons);
    event DescriptorUpdated(string newDescriptor);

    modifier onlyAdmin() {
        require(msg.sender == hubAdmin, "EcoCarbon: Access denied");
        _;
    }

    modifier whenNotHalted() {
        require(!isHubHalted, "EcoCarbon: Hub is halted");
        _;
    }

    constructor() {
        hubAdmin = payable(msg.sender);
        hubDescriptor = "Eco Base Carbon Credit Hub v1";
        platformFeeBps = 250; // 2.5%
        isHubHalted = false;
        certifiedProjects[msg.sender] = true;
    }

    // 1. addCertifiedProject
    function addCertifiedProject(address projectOwner) external onlyAdmin {
        require(!certifiedProjects[projectOwner], "EcoCarbon: Already certified");
        certifiedProjects[projectOwner] = true;
        emit ProjectCertified(projectOwner);
    }

    // 2. buyCarbonCredits
    function buyCarbonCredits(uint256 batchId, uint256 tonsToBuy) external payable whenNotHalted {
        CreditBatch storage b = creditBatches[batchId];
        require(batchId > 0 && batchId <= batchCounter, "EcoCarbon: Invalid ID");
        require(b.isActive, "EcoCarbon: Batch inactive");
        require(tonsToBuy > 0 && tonsToBuy <= b.availableTons, "EcoCarbon: Invalid tonnage");
        
        uint256 totalCost = tonsToBuy * b.pricePerTonWei;
        require(msg.value >= totalCost, "EcoCarbon: Insufficient payment");

        uint256 fee = (totalCost * platformFeeBps) / 10000;
        uint256 ownerShare = totalCost - fee;

        accumulatedFees += fee;
        b.availableTons -= tonsToBuy;

        // Если купили остаток, закрываем листинг
        if (b.availableTons == 0) {
            b.isActive = false;
        }

        if (ownerShare > 0) {
            (bool sent, ) = b.projectOwner.call{value: ownerShare}("");
            require(sent, "EcoCarbon: Payout failed");
        }

        // Возврат сдачи, если отправили больше нужного
        if (msg.value > totalCost) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(refunded, "EcoCarbon: Refund failed");
        }

        emit CreditsPurchased(batchId, msg.sender, tonsToBuy, totalCost);
    }

    // 3. cancelCreditListing
    function cancelCreditListing(uint256 batchId) external {
        CreditBatch storage b = creditBatches[batchId];
        require(batchId > 0 && batchId <= batchCounter, "EcoCarbon: Invalid ID");
        require(msg.sender == b.projectOwner || msg.sender == hubAdmin, "EcoCarbon: Unauthorized");
        require(b.isActive, "EcoCarbon: Already inactive");

        b.isActive = false;
        emit ListingCanceled(batchId);
    }

    // 4. depositHubTreasury
    function depositHubTreasury() external payable whenNotHalted {
        require(msg.value > 0, "EcoCarbon: Zero deposit");
        accumulatedFees += msg.value;
        emit TreasuryDeposited(msg.sender, msg.value);
    }

    // 5. emptyHubReserves
    function emptyHubReserves() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "EcoCarbon: Zero balance");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: balance}("");
        require(sent, "EcoCarbon: Sweep failed");

        emit ReservesEmptied(hubAdmin, balance);
    }

    // 6. gatherPlatformFees
    function gatherPlatformFees() external onlyAdmin {
        uint256 amount = accumulatedFees;
        require(amount > 0, "EcoCarbon: Zero fees");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: amount}("");
        require(sent, "EcoCarbon: Harvest failed");

        emit FeesGathered(hubAdmin, amount);
    }

    // 7. haltCarbonHub
    function haltCarbonHub(bool isHalted) external onlyAdmin {
        isHubHalted = isHalted;
        emit HubHaltToggled(isHalted);
    }

    // 8. listCarbonCredits
    function listCarbonCredits(uint256 pricePerTonWei, uint256 totalTons, bytes32 certHash) external whenNotHalted returns (uint256) {
        require(certifiedProjects[msg.sender], "EcoCarbon: Not a certified project");
        require(pricePerTonWei > 0 && totalTons > 0, "EcoCarbon: Invalid parameters");

        batchCounter++;
        creditBatches[batchCounter] = CreditBatch({
            projectOwner: payable(msg.sender),
            pricePerTonWei: pricePerTonWei,
            availableTons: totalTons,
            isActive: true,
            certificationHash: certHash
        });

        emit CreditsListed(batchCounter, msg.sender, pricePerTonWei, totalTons);
        return batchCounter;
    }

    // 9. retireCarbonCredits
    function retireCarbonCredits(uint256 tonsToRetire) external whenNotHalted {
        require(tonsToRetire > 0, "EcoCarbon: Zero tons");
        
        // Симуляция сжигания купленных кредитов (в реальности нужна привязка к балансу пользователя)
        retiredCreditsByCompany[msg.sender] += tonsToRetire;
        
        emit CreditsRetired(msg.sender, tonsToRetire);
    }

    // 10. updateHubDescriptor
    function updateHubDescriptor(string calldata newDescriptor) external onlyAdmin {
        require(bytes(newDescriptor).length > 0, "EcoCarbon: Empty string");
        hubDescriptor = newDescriptor;
        emit DescriptorUpdated(newDescriptor);
    }
}