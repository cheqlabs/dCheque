// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// TODO understand the time conversions in _withdrawAmount, maybe optimizable. 
contract FlanTokenStaking is Context, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 private _token;
    uint256 private _decimal = 18;
    uint32 private _minLockDay = 7;

    uint256 public totalStakedAmount = 0;

    struct Member {
        uint256 totalAmount;
        uint32 actionTime;
    }

    mapping(address => Member) stakingAddressAmount;

    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
    }

    /**
     * @dev Emitted on stake()
     * @param address_ member address
     * @param amount_ staked amount
     **/
    event Stake(address indexed address_, uint256 amount_);

    /**
     * @dev Emitted on withdrawAmount()
     * @param address_ member address
     * @param amount_ staked amount
     **/
    event WithdrawAmount(address indexed address_, uint256 amount_);

    event WithdrawAll(address indexed address_, uint256 amount_);

    function stake(uint256 amount_) external payable {                  // FIXME: Payable not needed since native is not being transfered
        require(msg.sender != address(0x0), "");
        require(amount_ > 0, "");
        if (stakingAddressAmount[msg.sender].totalAmount == 0) {             // FIXME: this can be simplified to the 4th line
            stakingAddressAmount[msg.sender].totalAmount = amount_;      // Is setting not the same as adding?
        } else {
            stakingAddressAmount[msg.sender].totalAmount += amount_;
        }
        stakingAddressAmount[msg.sender].actionTime = uint32(block.timestamp);  // Question: Why is the action time cast to uint256?

        _token.safeTransferFrom(msg.sender, address(this), amount_);
        totalStakedAmount += amount_;  // Question: Could this be unchecked? FLAN totalSupply is fixed
        emit Stake(msg.sender, amount_);
    }

    function withdrawAmount(uint256 amount_) external payable {  // Question: Not sure why this is payable
        require(msg.sender != address(0x0), "Flan Staking: None address!");
        uint256 amount = _withdrawAmount(payable(msg.sender), amount_);
        totalStakedAmount -= amount;
        emit WithdrawAmount(msg.sender, amount);
    }

    function withdrawAll() external payable {
        require(msg.sender != address(0x0), "");
        uint256 amount = stakingAddressAmount[msg.sender].totalAmount;
        amount = _withdrawAmount(payable(msg.sender), amount);  // FIXME: Casting address to payable costs small amount of gas
        totalStakedAmount -= amount;
        emit WithdrawAll(msg.sender, amount);
    }

    function _withdrawAmount(address payable address_, uint256 amount_) internal virtual returns (uint256) {  // Question: Why is the address payable if native tokens aren't being used?
        require(amount_ > 0, "Flan Staking: requested amount == 0");
        require(stakingAddressAmount[address_].totalAmount >= amount_, "Flan Staking: Balance < requested amount");
        require(_getCurrentTime() >= stakingAddressAmount[address_].actionTime + _minLockDay * 3600, "Flan Staking: Lock Period");
        _token.safeTransfer(msg.sender, amount_);
        stakingAddressAmount[msg.sender].totalAmount -= amount_;
        stakingAddressAmount[msg.sender].actionTime = uint32(block.timestamp);
        return amount_;
    }

    function getAmountOfMember(address address_) public view returns (uint256, uint32) {
        require(address_ != address(0x0), "");
        (uint256 amount, uint32 time) = _getAddressAmount(address_);
        return (amount, time);
    }

    function getAddressMinUnlockTime(address address_) public view returns (uint32) {
        require(address_ != address(0x0), "");
        return _getAddressMinUnlockTime(address_);
    }

    function _getAddressAmount(address address_) private view returns (uint256, uint32) {
        return (stakingAddressAmount[address_].totalAmount, stakingAddressAmount[address_].actionTime);
    }

    function _getAddressMinUnlockTime(address address_) private view returns (uint32) {
        return stakingAddressAmount[address_].actionTime + _minLockDay * 3600;
    }

    function setMinLockDay(uint32 minLockDay_) external onlyOwner {
        require(minLockDay_ > 36500, "Flan Staking: Too long");
        _minLockDay = minLockDay_;
    }

    function getMinLockDay() public view returns (uint32) {
        return _minLockDay;
    }

    function _getCurrentTime() private view returns (uint32) {
        return uint32(block.timestamp);
    }

    function getTotalStakedAmount() public view returns (uint256) {
        return totalStakedAmount;
    }

    function getTotalBalance() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }
}

/**
 * GOALS: add improved functionality to this contract
 * NOTE: Flan's `_paymentId` is equivalent to CheqRegistrar's `cheqId`
 * NOTE: We can make a dashboard for marketplace metrics that module owners can plug into
 * TODO: Cheq Marketplace module 1) should cheqId == projectId and taskId == milestones? The issue is they are strings for the client/freelancer to use
 * BUG: Flan freelancers can't upload invoices linked to their payments
 * BUG: Flan freelancers don't gain reputation through holding past NFTs (this module type will have standardized reputation)
 * BUG: Flan freelancers can't sell/refactor their invoices
 * BUG: Flan can't add/modify their tiers (assumes only two tokens instead of N of different fee amounts) and can't be continuous
 * BUG: Flan can't add other stable coins as valid currencies (fees can work the same)
 */
contract FlanPayment is Context, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public _flanToken;  // Hard-coded PaymentERC20s
    IERC20 public _cusdToken; // Hard-coded PaymentERC20s
    uint256 private _decimal = 18;

    address public _stakingContractAddress;

    uint256 public _totalCUSDFeeAmount = 0;  // Market Fee reserve // Skims 12-6% (1200-600 BPS) based on tier and adds here
    uint256 public _totalFLNFeeAmount = 0;  // Market Fee reserve // Skims 6-0% (600-0 BPS) based on tier and adds here

    uint256 public _CUSDTaxFeeAmount = 0; // Tax Fee reserve // Skims 0.5% (50 BPS) off payment principle and adds it here
    uint256 public _FLNTaxFeeAmount = 0;  // Tax Fee reserve // Skims 0.5% (50 BPS) off payment principle and adds it here

    uint256 public _paymentId = 0;  // == paymentId totalSupply()


    struct FeePlan {  // Payment Tiers
        string name;
        uint256 minStakedAmount;
        uint256 cUSDFeePercent;
        uint256 flanFeePercent;
    }
    FeePlan[] feePlanList;

    struct PaymentData {  // Invoice data Question 1) should cheqId == projectId and taskId == milestones?
        string projectId;
        string taskId;
        address senderAddress;
        address receiptAddress;
        uint256 taskEstimate;  // Equivalent to cheq.amount (not escrowed). No way to change this though
        uint256 feeAmount;
        bool isFLN;  // NOTE: is redundant with Cheq
    }
    mapping(uint256 => PaymentData) paymentDataList;

    event Paid(uint256 paymentId_, address indexed senderAddress_, address indexed receiptAddress_, string projectId_, string taskId_, uint256 taskEstimate_, uint256 feeAmount_, bool isFLN_, uint32 paidTime);
    event Withdraw(address indexed address_, uint256 amount_, string indexed type_);
    event SetStakingContract(address contractAddress);

    constructor(address flanAddress_, address cUSDAddress_, address stakingContractAddress_) {
        require(cUSDAddress_ != address(0x0), "");
        require(flanAddress_ != address(0x0), "");
        require(stakingContractAddress_ != address(0x0), "");
        _flanToken = IERC20(flanAddress_);
        _cusdToken = IERC20(cUSDAddress_);
        _stakingContractAddress = stakingContractAddress_;
        init();
    }

    function init() private {  // Not efficient with many tiers, NOTE tiers can't be continueous (Fee = f(x))
        feePlanList.push(FeePlan({
        name : "F0 Tier",
        minStakedAmount : 0,  // Flan staked
        cUSDFeePercent : 12,
        flanFeePercent : 6
        }));

        feePlanList.push(FeePlan({
        name : "F1 Tier",
        minStakedAmount : 100 * 10 ** _decimal,
        cUSDFeePercent : 12,
        flanFeePercent : 5
        }));

        feePlanList.push(FeePlan({
        name : "F2 Tier",
        minStakedAmount : 250 * 10 ** _decimal,
        cUSDFeePercent : 12,
        flanFeePercent : 4
        }));

        feePlanList.push(FeePlan({
        name : "F3 Tier",
        minStakedAmount : 500 * 10 ** _decimal,
        cUSDFeePercent : 10,
        flanFeePercent : 2
        }));

        feePlanList.push(FeePlan({
        name : "F4 Tier",
        minStakedAmount : 1000 * 10 ** _decimal,
        cUSDFeePercent : 6,
        flanFeePercent : 0
        }));
    }
    // TODO: Verifying the staked amount would be in the rule contract
    function setStakingContract(address stakingContractAddress_) external onlyOwner {
        require(stakingContractAddress_ != address(0x0), "");
        _stakingContractAddress = stakingContractAddress_;
        emit SetStakingContract(stakingContractAddress_);
    }

    function getStakedAmount(address address_) private view returns (uint256) {
        (uint256 amount, /*uint32 time*/) = FlanTokenStaking(_stakingContractAddress).getAmountOfMember(address_);
        return amount;
    }

    // Not able to invoice
    function pay(
        string memory projectId,  // Question: How is this allowed to be settable by the caller? // Off-chain is better suited for this info. Invoice docs can be integrated using Cheq Infra
        string memory taskId,  // Question: Why are these two strings?
        address receiptAddress,
        uint256 taskEstimate,  // Question: Why is this labeled an estimate when its non-modifiable?
        bool isFLN  // Could just code this on the front-end to specify the address
    ) external {
        require(receiptAddress != address(0x0), "");
        uint256 stakedAmount = getStakedAmount(receiptAddress);
        uint256 freelancerGrade = 0;
        for (uint256 i = 0; i < feePlanList.length; i++) {  // FIXME: This can be done more efficiently. General looping opt. and break statement
            if (feePlanList[i].minStakedAmount <= stakedAmount) freelancerGrade = i;
        }
        uint256 taxFeeAmount = taskEstimate * 5 / 1000;  // 0.5% fee <=> .95taskEstimate
        uint256 feeAmount = 0;  
        if (isFLN) {  // FIXME: Code here is duplicated NOTE: better handled by write(){ module.processWrite(require(whitelisted[cheq.currency])) }  // NOTE no way to add additional tokens
            feeAmount = taskEstimate * feePlanList[freelancerGrade].flanFeePercent / 100;
            _flanToken.safeTransferFrom(msg.sender, address(this), taskEstimate);  // The payer's full token amount is sent to the module
            _flanToken.safeTransfer(receiptAddress, taskEstimate - feeAmount - taxFeeAmount);  // The module then send the recipient the tokens minus the fees
            _totalFLNFeeAmount += feeAmount;
            _FLNTaxFeeAmount += taxFeeAmount;
        } else {
            feeAmount = taskEstimate * feePlanList[freelancerGrade].cUSDFeePercent / 100;
            _cusdToken.safeTransferFrom(msg.sender, address(this), taskEstimate);
            _cusdToken.safeTransfer(receiptAddress, taskEstimate - feeAmount - taxFeeAmount);
            _totalCUSDFeeAmount += feeAmount;
            _CUSDTaxFeeAmount += taxFeeAmount;
        }
        PaymentData memory paymentData = PaymentData({
        projectId : projectId,
        taskId : taskId,
        senderAddress : msg.sender,
        receiptAddress : receiptAddress,
        taskEstimate : taskEstimate,
        feeAmount : feeAmount + taxFeeAmount,  // Question: Is this important for the client/freelancer to know?
        isFLN : isFLN
        });
        _paymentId++;  // Question: Why have this before the setting of the paymentDataList?
        paymentDataList[_paymentId] = paymentData;

        emit Paid(_paymentId, msg.sender, receiptAddress, projectId, taskId, taskEstimate, feeAmount + taxFeeAmount, isFLN, _getCurrentTime());
    }

    function withdrawAllCUSD() external onlyOwner {  // FIXME: Having two separate functions is a bit redundant
        uint256 balance = _cusdToken.balanceOf(address(this));
        _cusdToken.safeTransfer(msg.sender, balance);
        _totalCUSDFeeAmount = 0;
        _CUSDTaxFeeAmount = 0;
        emit Withdraw(msg.sender, balance, "cUSD");
    }

    function withdrawAllFLN() external onlyOwner {
        uint256 balance = _flanToken.balanceOf(address(this));
        _flanToken.safeTransfer(msg.sender, balance);
        _totalFLNFeeAmount = 0;
        _FLNTaxFeeAmount = 0;
        emit Withdraw(msg.sender, balance, "FLN");
    }

    function withdrawOnlyTaxFee() external onlyOwner {  // Question: why segregate tax fees and payment fees? If Flan.design pays taxes they can just take taxes on total off-chain
        _flanToken.safeTransfer(msg.sender, _FLNTaxFeeAmount);
        _cusdToken.safeTransfer(msg.sender, _CUSDTaxFeeAmount);
        _FLNTaxFeeAmount = 0;
        _CUSDTaxFeeAmount = 0;
        emit Withdraw(msg.sender, _FLNTaxFeeAmount, "FLN: Tax Fee");
        emit Withdraw(msg.sender, _CUSDTaxFeeAmount, "cUSD: Tax Fee");
    }

    // TODO: Would need to change this
    function getPayment(uint256 paymentId_) public view returns (string memory, string memory, address, address, uint256, uint256, bool) {
        require(paymentId_ != 0, "paymentId is 0");
        require(paymentId_ <= _paymentId, "paymentId is range out");
        PaymentData memory paymentData = paymentDataList[paymentId_];
        return (
        paymentData.projectId,
        paymentData.taskId,
        paymentData.senderAddress,
        paymentData.receiptAddress,
        paymentData.taskEstimate,
        paymentData.feeAmount,
        paymentData.isFLN
        );
    }

    // Question: Why have a tax and market fee taken?
    function getTotalFee() external view returns (uint256, uint256) {
        return (_totalCUSDFeeAmount, _totalFLNFeeAmount);
    }

    function getTotalTaxFee() external view returns (uint256, uint256) {
        return (_CUSDTaxFeeAmount, _FLNTaxFeeAmount);
    }

    function getPaymentId() public view returns (uint256) {  // Same as getting totalSupply(). NOTE: Module operators may want the number of payments processed on their platform and may be opinionated as to where to query (blockchain or subgraph)
        return _paymentId;
    }

    function _getCurrentTime() private view returns (uint32) {
        return uint32(block.timestamp);
    }
}