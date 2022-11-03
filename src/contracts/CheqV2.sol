// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.14;
import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";

/* 
CRX: executes WTFC
Ownership (mint, transfer, ?burn)
Metadata (Cheq structs)
Deposit balances
ProtocolFees

Broker: conditionalizes WTFC
updates relevent internal variables

Essentially, tokens are double wrapped using this system:
    The token is wrapped in CRX as a Cheq (intrinsic properties), then wrapped by it's broker (conditional functions)
    CRX is the chess board while brokers are the movement rules

TODO: Add NFT forwarding functions to broker (including approvals)
*/


contract CRX is ERC721, Ownable {

    struct Cheq {
        uint256 amount;  // ? Broker can modify ?
        uint256 escrowed;  // Broker can modify [MOST VULNERABLE, corresponds to CRX deposits]
        IERC20 token;  // IMMUTABLE [not settable]
        address drawer; // IMMUTABLE [settable]
        address recipient; // IMMUTABLE [settable]
        ICheqBroker broker;  // IMMUTABLE [not settable]
    }
    /*//////////////////////////////////////////////////////////////
                           STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => Cheq) public cheqInfo; // Cheq information
    mapping(address => mapping(IERC20 => uint256)) public deposits; // Total user deposits
    uint256 public totalSupply; // Total cheques created
    uint256 public protocolFee; // Fee in native token taken
    uint256 public protocolReserve; // Fee in native token taken
    // uint256 public writeFee;
    // uint256 public transferFee; // Fee in native token taken
    // uint256 public fundFee;
    // uint256 public cashFee;

    /*//////////////////////////////////////////////////////////////
                           EVENTS/MODIFIERS
    //////////////////////////////////////////////////////////////*/
    event Deposit(IERC20 indexed _token, address indexed to, uint256 amount);
    event Write(uint256 indexed tokenId, uint256 amount, uint256 escrowed, IERC20 token, address drawer, address indexed recipient, ICheqBroker indexed broker); 
    //    Transfer() // Inherited from IERC721
    event Fund(uint256 indexed cheqId, address from, uint256 amount);
    event Cash(address indexed bearer, uint256 indexed tokenId, uint256 cashingAmount);
    event SetProtocolFee(uint256 amount);  // TODO figure out protocol fee structure (just on deposit?)
    event Withdraw(address indexed _address, uint256 amount);  // Protocol fees
    
    modifier onlyCheqBroker(uint256 cheqId){require(address(cheqInfo[cheqId].broker)==msg.sender, "Only Cheq's broker");_;}

    /*//////////////////////////////////////////////////////////////
                        ONLY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() ERC721("CheqProtocol", "CHEQ") {}

    function setFees(uint256 _protocolFee)
        external
        onlyOwner
    {
        protocolFee = _protocolFee;
        emit SetProtocolFee(_protocolFee);
    }
    function withdrawFees(uint256 _amount) external onlyOwner {
        // require(protocolReserve >= _amount, "More than available");
        // unchecked {
        //     protocolReserve -= _amount;
        // }
        // bool success = payable(address(this)).call(
        //     _msgSender(),
        //     _amount
        // );
        // require(success, "Transfer failed.");
        // emit Withdraw(_msgSender(), _amount);
    }
    /*//////////////////////////////////////////////////////////////
                            USER DEPOSITS
    //////////////////////////////////////////////////////////////*/
    function _deposit(
        IERC20 _token,
        address from,
        uint256 _amount
    ) private {
        require(_amount > 0, "Zero deposit");
        require(_token.transferFrom(
            from,
            address(this),
            _amount
        ), "Transfer failed");
        deposits[from][_token] += _amount;
        emit Deposit(_token, from, _amount);
    }

    function deposit(IERC20 _token, uint256 _amount) public returns (bool) {  // make one external and use other in depositWrite()?
        _deposit(_token, _msgSender(), _amount);
        return true;
    }

    function deposit(
        address from,
        IERC20 _token,
        uint256 _amount
    ) public returns (bool) {
        _deposit(_token, from, _amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                          ERC-721 OVERRIDES
    //////////////////////////////////////////////////////////////*/
    function _feeOnTransfer(uint256 cheqId) private {  // Reduce escrowed amount on transfer
        // Cheq storage Cheq = cheqInfo[cheqId];
        // IERC20 _token = Cheq.token;
        // require(Cheq.amount >= protocolFee[_token], "too small for transfer");
        // unchecked {
        //     Cheq.amount = Cheq.amount - protocolFee[_token];
        // }
        // protocolReserve[_token] += protocolFee[_token];
    }  // Should this be in CRX?

    function transferFrom(
        address from,
        address to,
        uint256 cheqId
    ) public onlyCheqBroker(cheqId) virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), cheqId),
            "Transfer disallowed"
        );
        _feeOnTransfer(cheqId);  // TODO switch with yield
        _transfer(from, to, cheqId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 cheqId,
        bytes memory data
    ) public onlyCheqBroker(cheqId) virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), cheqId),
            "Transfer disallowed"
        );
        _feeOnTransfer(cheqId);  // TODO switch with yield
        _safeTransfer(from, to, cheqId, data);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-721 FUNCTION USAGE
    //////////////////////////////////////////////////////////////*/
    function _initCheq (
        address drawer,
        IERC20 _token,
        uint256 amount,
        uint256 escrowed,
        address recipient,
        ICheqBroker broker
        ) private pure returns(Cheq memory){
        return Cheq({
            drawer: drawer,
            recipient: recipient,
            token: _token,
            amount: amount,
            escrowed: escrowed, 
            broker: broker
        });
    }

    function write(
        address from,
        address recipient,
        IERC20 _token,
        uint256 amount,
        uint256 escrowed,
        ICheqBroker broker,
        address owner
    ) public 
        returns (uint256)
    {
        require(
            amount <= deposits[from][_token],
            "INSUF_BAL"
        );
        require(msg.sender==address(broker), "Only Broker");
        deposits[from][_token] -= amount;
        cheqInfo[totalSupply] = _initCheq(from, _token, amount, escrowed, recipient, broker);
        emit Write(totalSupply, amount, escrowed, _token, from, recipient, broker);
        _safeMint(owner, totalSupply);
        totalSupply += 1;
        return totalSupply-1;
    }

    function cash(uint256 cheqId, address to, uint256 cashAmount) external onlyCheqBroker(cheqId) {
        Cheq storage cheq = cheqInfo[cheqId]; 
        require(cheq.escrowed>=cashAmount, "Can't cash more than available");
        cheq.escrowed -= cashAmount;
        require(cheq.token.transfer(to, cashAmount), "Transfer failed");
        emit Cash(to, cheqId, cashAmount);
    }

    function fund(uint256 cheqId, address from, uint256 amount) external onlyCheqBroker(cheqId) {
        Cheq storage cheq = cheqInfo[cheqId]; 
        IERC20 _token = cheq.token;
        require(amount <= deposits[from][_token], "INSUF_BAL");
        deposits[from][_token] -= amount;
        cheq.escrowed += amount;
        emit Fund(cheqId, from, amount);
    }

    function depositWrite(
        address from,
        IERC20 _token,
        uint256 amount,
        uint256 escrowed,
        address recipient,
        ICheqBroker broker, 
        address owner
        ) external
        returns (uint256){
        require(deposit(from, _token, amount), "deposit failed");
        return write(from, recipient, _token, amount, escrowed, broker, owner);
    }  // TODO let the broker handle this? Or keep it here and broker can use switch to call write() || depositWrite()
    function cheqAmount(uint256 cheqId) external view returns (uint256) {
        return cheqInfo[cheqId].amount;
    }
    function cheqToken(uint256 cheqId) external view returns (IERC20) {
        return cheqInfo[cheqId].token;
    }
    function cheqDrawer(uint256 cheqId) external view returns (address) {
        return cheqInfo[cheqId].drawer;
    }
    function cheqRecipient(uint256 cheqId) external view returns (address) {
        return cheqInfo[cheqId].recipient;
    }
    function cheqEscrowed(uint256 cheqId) external view returns (uint256) {
        return cheqInfo[cheqId].escrowed;
    }
    function cheqBroker(uint256 cheqId) external view returns (ICheqBroker) {
        return cheqInfo[cheqId].broker;
    }
}


interface ICheqBroker {
    // IDK how ERC721 approval functions figure into this
    function isWriteable(address sender, IERC20 _token, uint256 amount, uint256 escrowed, address recipient, address owner) external view returns(bool);
    // Checks if caller can write the cheq [INTERFACE: broker] (isWriteable)
    // Checks if caller has enough balance [Cheq]
    //// Checks if recipient/Cheq allows this broker [Cheq]
    // Pays auditor [INTERFACE: auditor]
    // Deducts user balance [Cheq]
    // Initializes cheqInfo [Cheq]
    // Emits WriteCheque [Cheq]
    // Mints Cheq [Cheq]
    // Calls onWrite() [INTERFACE]
    // Increments totalSupply [Cheq]
    // Returns cheqId (totalsupply) [Cheq]
    // PROTOCOL FEE [Cheq]
    ///// function Write(uint256 cheqId, address sender, IERC20 _token, uint256 amount, uint256 escrowed, address recipient) external returns(bool);
    // Updates the broker contract's variables
    
    function isTransferable(uint256 cheqId, address caller) external view returns(bool);
    // Checks if caller isOwner 
    // Transfers
    // PROTOCOL FEE [Cheq]
    //// function transfer(uint256 cheqId, address caller) external view;

    function fundable(uint256 cheqId, address caller, uint256 amount) external view returns(uint256);
    // Checks if the caller has enough in crx.deposits[caller][cheq.token]
    
    function cashable(uint256 cheqId, address caller) external view returns(uint256);  // How much can be cashed
    // Checks if caller is the owner [INTERFACE: broker]
    // Checks if is cashable [INTERFACE: broker]
    // Sets as cashed [CHEQ OR INTERFACE?]
    // Transfers the cashing amount [Cheq]
    // Emits Cash event [Cheq]
    // PROTOCOL FEE [Cheq]
    // AUDITOR FEE [INTERFACE: auditor]
    //// THIS MIGHT NOT NEED TO BE IN [CHEQ] SINCE IT ONLY AFFECTS CASHABLE
    // function isVoidable(uint256 cheqId, address caller) external returns(bool);
    // Checks if caller is auditor [INTERFACE]
    // Checks if check is voidable by auditor []
    // Sets cash status []
    // Pays auditor []
    // Increments balance back to drawer
    // Emits Void event [Cheq]
    // PROTOCOL FEE [Cheq]
    // function cash() external returns (bool);
    function status(uint256 cheqId, address caller) external view returns(string memory);  // TODO Could this be used maliciously?
    // 0:Pending, 1:Ready, 2:Settled, 3:Rejected  
    // Refunded/voided, Spited, Disputing, Frozen, Burnt, Mature
}


interface IAuditFeeResolver {  // Execute fee or just return it?
    function onWrite() external returns(uint256);
    function onCash() external returns(uint256);
    function onVoid() external returns(uint256);
    function onTransfer() external returns(uint256);
}

contract SelfSignTimeLock is ICheqBroker {  
    CRX public crx;
    // struct CheqWrapper {
    //     address auditor;
    //     uint256 created;
    //     uint256 inspectionDuration;
    //     bool isVoided;
    // }
    // mapping(uint256 => CheqWrapper) public cheqWrappers;
    mapping(uint256 => address) public cheqAuditor;
    mapping(uint256 => uint256) public cheqCreated;
    mapping(uint256 => uint256) public cheqInspectionPeriod;
    mapping(uint256 => bool) public cheqVoided;
    // mapping(address => bool) public acceptsBroker;  // Allow users to opt-in?

    constructor(CRX _crx){
        crx = _crx;
    }
    function isWriteable(address, IERC20, uint256, uint256, address, address) public pure returns(bool) { 
        // return acceptsBroker[sender] && acceptsBroker[recipient] && acceptsBroker[owner];  // See if writer has enough deposit on Cheq or let Cheq do that?
        return true;
    }

    function writeCheque(
        IERC20 _token,
        uint256 amount,
        uint256 escrowed,
        address recipient,
        address owner,
        address auditor,
        uint256 inspectionPeriod
        ) external returns(uint256){
        // require(isWriteable(msg.sender, _token, amount, escrowed, recipient, owner), "Not writeable");  // Customary
        uint256 cheqId = crx.write(msg.sender, recipient, _token, amount, escrowed, this, owner);  // TODO Rewrite arg order to a standard form across write_()
        cheqCreated[cheqId] = block.timestamp;
        cheqAuditor[cheqId] = auditor;
        cheqInspectionPeriod[cheqId] = inspectionPeriod;
        // cheqWrappers[cheqId] = CheqWrapper({auditor: auditor, created: block.timestamp, inspectionDuration: inspectionPeriod, isVoided:false});
        return cheqId;
    }

    function isTransferable(uint256 cheqId, address caller) public view returns(bool){
        // cheq._isApprovedOrOwner(caller, cheqId);  // Need to find out if this is true and return it
        return crx.ownerOf(cheqId)==caller;
    }

    function fundable(uint256 cheqId, address caller, uint256 amount) public view returns(uint256) {
        return 0;
    }

    function cashable(uint256 cheqId, address caller) public view returns(uint256) {  // Let anyone see what's cashable, ALSO 
        if (block.timestamp >= cheqCreated[cheqId]+cheqInspectionPeriod[cheqId] 
            || crx.ownerOf(cheqId)!=caller 
            || cheqVoided[cheqId]){
            return 0;
        } else{
            return crx.cheqEscrowed(cheqId);
        }
    }

    function cashCheque(uint256 cheqId) external {
        // require(cheq.ownerOf(cheqId)==msg.sender, "Non-owner");  // Keep this check to let user know they don't own it?
        uint256 cashingAmount = cashable(cheqId, msg.sender);
        require(cashingAmount>0, "Not cashable");
        crx.cash(cheqId, msg.sender, cashingAmount);
    }
    
    function voidCheque(uint256 cheqId) external {
        require(cheqAuditor[cheqId]==msg.sender, "Only auditor");
        cheqVoided[cheqId] = true;
        crx.cash(cheqId, crx.cheqDrawer(cheqId), crx.cheqEscrowed(cheqId));  // Return escrow to drawer
    }
    function status(uint256 cheqId, address caller) public view returns(string memory){
        if(cashable(cheqId, caller) != 0){
            return "mature";
        } else if(cheqVoided[cheqId]){
            return "voided";
        } else {
            return "pending";
        }
    }
}

contract HandshakeTimeLock is ICheqBroker {
    CRX public crx;

    constructor(CRX _crx){
        crx = _crx;
    }

    mapping(address => mapping(address => bool)) public userAuditor; // Whether User accepts Auditor
    mapping(address => mapping(address => bool)) public auditorUser; // Whether Auditor accepts User  
    // mapping(address => mapping(address => address)) public acceptedCombos;  // Whether this combination of user-auditor-user exists (not address(0)). ASSUMES ONLY MANY-1 RELATIONSHIP BETWEEN USERS AND AUDITOR
    mapping(uint256 => address) public cheqAuditor;
    mapping(uint256 => uint256) public cheqCreated;
    mapping(uint256 => uint256) public cheqInspectionPeriod;
    mapping(uint256 => bool) public cheqVoided; 


    function isWriteable(address sender, IERC20 _token, uint256 amount, uint256 escrowed, address recipient, address owner) public pure returns(bool) { 
        return false;// TODO HOW TO ADD EXTRA INFO HERE? BYTES PARAMETER?
    }

    function writeCheque(
        IERC20 _token,
        uint256 amount,
        uint256 escrowed,
        address recipient,
        address owner,
        address auditor,
        uint256 inspectionPeriod
        ) external returns(uint256){
        require(isWriteable(msg.sender, _token, amount, escrowed, recipient, owner), "Not writeable");  // Customary
        uint256 cheqId = crx.write(msg.sender, recipient, _token, amount, escrowed, this, owner);  // TODO Rewrite arg order to a standard form across write_()
        cheqCreated[cheqId] = block.timestamp;
        cheqAuditor[cheqId] = auditor;
        cheqInspectionPeriod[cheqId] = inspectionPeriod;
        // cheqWrappers[cheqId] = CheqWrapper({auditor: auditor, created: block.timestamp, inspectionDuration: inspectionPeriod, isVoided:false});
        return cheqId;
    }

    function isTransferable(uint256 cheqId, address caller) public view returns(bool){
        // cheq._isApprovedOrOwner(caller, cheqId);  // Need to find out if this is true and return it
        return crx.ownerOf(cheqId)==caller;
    }

    function fundable(uint256 cheqId, address caller, uint256 amount) public view returns(uint256) {
        return 0;
    }

    function cashable(uint256 cheqId, address caller) public view returns(uint256) {  // Let anyone see what's cashable, ALSO 
        if (block.timestamp >= cheqCreated[cheqId]+cheqInspectionPeriod[cheqId] 
            || crx.ownerOf(cheqId)!=caller 
            || cheqVoided[cheqId]){
            return 0;
        } else{
            return crx.cheqEscrowed(cheqId);
        }
    }

    function cashCheque(uint256 cheqId) external {
        // require(cheq.ownerOf(cheqId)==msg.sender, "Non-owner");  // Keep this check to let user know they don't own it?
        uint256 cashingAmount = cashable(cheqId, msg.sender);
        require(cashingAmount>0, "Not cashable");
        crx.cash(cheqId, msg.sender, cashingAmount);
    }
    
    function voidCheque(uint256 cheqId) external {
        require(cheqAuditor[cheqId]==msg.sender, "Only auditor");
        cheqVoided[cheqId] = true;
        crx.cash(cheqId, crx.cheqDrawer(cheqId), crx.cheqEscrowed(cheqId));  // Return escrow to drawer
    }
    function status(uint256 cheqId, address caller) public view returns(string memory){
        if(cashable(cheqId, caller) != 0){
            return "mature";
        } else if(cheqVoided[cheqId]){
            return "voided";
        } else {
            return "pending";
        }
    }
}