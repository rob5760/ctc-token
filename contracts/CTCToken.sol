pragma solidity ^0.4.11;

library SafeMath {
    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract Ownable {
  address public owner;


  /** 
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner. 
   */
  modifier onlyOwner() {
    if (msg.sender != owner) {
      throw;
    }
    _;
 }
 
}
  
contract ERC20 {

    function totalSupply() constant returns (uint256);
    function balanceOf(address who) constant returns (uint256);
    function transfer(address to, uint256 value);
    function transferFrom(address from, address to, uint256 value);
    function approve(address spender, uint256 value);
    function allowance(address owner, address spender) constant returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

}

contract HolderBonus{
    address public holder;
    uint256 public  bonusAmount;
}

contract CTCToken is Ownable, ERC20 {

    using SafeMath for uint256;

    // Token properties
    string public name = "ChainTrade Coin";
    string public symbol = "CTC";
    uint256 public decimals = 18;

	uint256 public initialPrice = 1000;
    uint256 public _totalSupply = 1000000000e18;

    uint256 public _icoSupply = 200000000e18;

    uint256 public _futureDistributionsSupply = 800000000e18;

    // Balances for each account
    mapping (address => uint256) balances;

    // Owner of account approves the transfer of an amount to another account
    mapping (address => mapping(address => uint256)) allowed;
    
    // Balances for each account KYC account approved
    mapping (address => bool) balancesKycAllowed;

    // start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime = 1507539600; //9/10/2017 9h GMT
    uint256 public endTime = 1514764799;  //31/12/2017 23h59:59 GMT

    HolderBonus holderBonus;


    // Owner of Token
    address public owner;

    // Wallet Address of Token
    address public multisig;

    // how many token units a buyer gets per wei
    uint256 public RATE;

    uint256 public bonusThreshold;
    uint256 public bonusAmount;

    uint256 public minContribAmount = 0.01 ether;

    uint256 public hardCap = 200000000e18;

    // amount of raised money in wei
    uint256 public fundRaised;
	
	//number of tokens sold 
	uint256 public numberTokenSold;

    bool public mintingFinished = false;

    bool public tradable = false;

    bool public active = true;

    event MintFinished();
    event StartTradable();
    event PauseTradable();
    event HaltTokenAllOperation();
    event ResumeTokenAllOperation();
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


    modifier canMint() {
        require(!mintingFinished);
        _;
    }

    modifier canTradable() {
        require(tradable);
        _;
    }

    modifier isActive() {
        require(active);
        _;
    }
    
    modifier saleIsOpen(){
        require(startTime >= getNow() && endTime >= startTime);
		_;
    }

    // Constructor
    // @notice CTCToken Contract
    // @return the transaction address
    function CTCToken(address _multisig, uint256 _bonusThreshold , uint256 _bonusAmount) {
        require(_multisig != 0x0);
        multisig = _multisig;
        RATE = initialPrice;
        bonusThreshold = _bonusThreshold;
        bonusAmount = _bonusAmount;

        balances[multisig] = _totalSupply;

        owner = msg.sender;
    }

    // Payable method
    // @notice Anyone can buy the tokens on tokensale by paying ether
    function () external payable {
        tokensale(msg.sender);
    }

    // @notice tokensale
    // @param recipient The address of the recipient
    // @return the transaction address and send the event as Transfer
    function tokensale(address recipient) canMint isActive saleIsOpen {
        require(recipient != 0x0);
		if(balancesKycAllowed[msg.sender] != true) {
		    refundFunds(msg.sender);
		    throw;
		}
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 nbTokens = weiAmount.mul(RATE).div(1 ether);
		numberTokenSold = nbTokens;
		
        require(_icoSupply >= nbTokens);
        
        bool tokensbonusApplicable = nbTokens >= bonusThreshold;
        if (tokensbonusApplicable) {
            nbTokens = nbTokens.add(bonusAmount);
        }
        // update state
        fundRaised = fundRaised.add(weiAmount);

        updateBalances(recipient, nbTokens);

        _icoSupply = _icoSupply.sub(nbTokens);

        TokenPurchase(msg.sender, recipient, weiAmount, nbTokens);

        forwardFunds();
    }
    
    function updateBalances(address receiver, uint tokens) internal {
        balances[multisig] = balances[multisig].sub(tokens);
        balances[receiver] = balances[receiver].add(tokens);
    }
    
    //refund back if not KYC approved
     function refundFunds(address origin) internal {
        origin.transfer(msg.value);
    }

    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        multisig.transfer(msg.value);
    }

    // @return true if the transaction can buy tokens
    function validPurchase() internal constant returns (bool) {
        bool withinPeriod = getNow() >= startTime && getNow() <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        bool minContribution = minContribAmount <= msg.value;
        bool notReachedHardCap = hardCap >= numberTokenSold;
        return withinPeriod && nonZeroPurchase && minContribution && notReachedHardCap;
    }
    
    function addAuthorizationForKycApproved(address userApprovedKyc) onlyOwner {
        require(userApprovedKyc != 0x0);
        balancesKycAllowed[userApprovedKyc] = true;
    }

    // @return true if crowdsale current lot event has ended
    function hasEnded() public constant returns (bool) {
        return getNow() > endTime;
    }

    function getNow() public constant returns (uint) {
        return (now * 1000);
    }

    // Set/change Multi-signature wallet address
    function changeMultiSignatureWallet (address _multisig) onlyOwner isActive {
        multisig = _multisig;
    }

    // Change ETH/Token exchange rate
    function changeTokenRate(uint _tokenPrice) onlyOwner isActive {
        RATE = _tokenPrice;
    }

    // Change Token contract owner
    function changeOwner(address _newOwner) onlyOwner isActive {
        owner = _newOwner;
    }

    // Set Finish Minting.
    function finishMinting() onlyOwner isActive {
        mintingFinished = true;
        MintFinished();
    }

    // Start or pause tradable to Transfer token
    function startTradable(bool _tradable) onlyOwner isActive {
        tradable = _tradable;
        if (tradable)
            StartTradable();
        else
            PauseTradable();
    }

    //UpdateICODateTime(uint256 _startTime,)
    function updateICODate(uint256 _startTime, uint256 _endTime) public onlyOwner {
        startTime = _startTime;
        endTime = _endTime;
    }
    
    //Change startTime to start ICO manually
    function changeStartTime(uint256 _startTime) onlyOwner {
        startTime = _startTime;
    }

    //Change endTime to end ICO manually
    function changeEndTime(uint256 _endTime) onlyOwner {
        endTime = _endTime;
    }

    // @return total tokens supplied
    function totalSupply() constant returns (uint256) {
        return _totalSupply;
    }

    // What is the balance of a particular account?
    // @param who The address of the particular account
    // @return the balanace the particular account
    function balanceOf(address who) constant returns (uint256) {
        return balances[who];
    }

    function balanceOfKyc(address investor) constant returns (bool) {
        bool kyC = balancesKycAllowed[investor];
        return kyC;
    }
	
	function balanceAddAllClientsAuthorizedForKyc(address[] listAddresses) onlyOwner {
		 for (uint256 i = 0; i < listAddresses.length; i++) {
			balancesKycAllowed[listAddresses[i]] = true;
		}
	}
	

	function addBonusForOneHolder(address holder, uint256 bonusToken) onlyOwner{
	     balances[holder] +=bonusToken;
	}

	
	function addBonusForMultipleHolders(HolderBonus[] holdersBonus) onlyOwner{
	    for (uint256 i = 0; i < holdersBonus.length; i++) {
			HolderBonus holder = holdersBonus[i];
			address holderAddress = holder.holder();
			uint256 bonus = holder.bonusAmount();
			balances[holderAddress] += bonus;
		}
	}
	
	function modifyBonusThreshold(uint256 _bonusThreshold) onlyOwner isActive {
		bonusThreshold = _bonusThreshold;
	}
	
	function modifyBonusAmount(uint256 _bonusAmount) onlyOwner isActive {
		bonusAmount = _bonusAmount;
	}

    // Send 800m to Company Wallet
    function sendfutureDistributionsSupplyToken(address to, uint256 value) onlyOwner isActive {
        require (
            to != 0x0 && value > 0 && _futureDistributionsSupply >= value
        );

        balances[multisig] = balances[multisig].sub(value);
        balances[to] = balances[to].add(value);
        _futureDistributionsSupply = _futureDistributionsSupply.sub(value);
        Transfer(multisig, to, value);
    }

    // @notice send `value` token to `to` from `msg.sender`
    // @param to The address of the recipient
    // @param value The amount of token to be transferred
    // @return the transaction address and send the event as Transfer
    function transfer(address to, uint256 value) canTradable isActive {
        require (
            balances[msg.sender] >= value && value > 0
        );
        balances[msg.sender] = balances[msg.sender].sub(value);
        balances[to] = balances[to].add(value);
        Transfer(msg.sender, to, value);
    }

    // @notice send `value` token to `to` from `from`
    // @param from The address of the sender
    // @param to The address of the recipient
    // @param value The amount of token to be transferred
    // @return the transaction address and send the event as Transfer
    function transferFrom(address from, address to, uint256 value) canTradable isActive {
        require (
            allowed[from][msg.sender] >= value && balances[from] >= value && value > 0
        );
        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(value);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
        Transfer(from, to, value);
    }

    // Allow spender to withdraw from your account, multiple times, up to the value amount.
    // If this function is called again it overwrites the current allowance with value.
    // @param spender The address of the sender
    // @param value The amount to be approved
    // @return the transaction address and send the event as Approval
    function approve(address spender, uint256 value) isActive {
        require (
            balances[msg.sender] >= value && value > 0
        );
        allowed[msg.sender][spender] = value;
        Approval(msg.sender, spender, value);
    }

    // Check the allowed value for the spender to withdraw from owner
    // @param owner The address of the owner
    // @param spender The address of the spender
    // @return the amount which spender is still allowed to withdraw from owner
    function allowance(address _owner, address spender) constant returns (uint256) {
        return allowed[_owner][spender];
    }

    // Get current price of a Token
    // @return the price or token value for a ether
    function getRate() constant returns (uint256 result) {
      return RATE;
    }
    
    function getTokenDetail() public constant returns (string, string, uint256, uint256, uint256, uint256, uint256 ) {
        return (name, symbol, startTime, endTime, _totalSupply, _icoSupply, _futureDistributionsSupply);
    }
}