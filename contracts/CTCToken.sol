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

contract IERC20 {

    function totalSupply() constant returns (uint256);
    function balanceOf(address who) constant returns (uint256);
    function transfer(address to, uint256 value);
    function transferFrom(address from, address to, uint256 value);
    function approve(address spender, uint256 value);
    function allowance(address owner, address spender) constant returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

}

contract CTCToken is IERC20 {

    using SafeMath for uint256;

    // Token properties
    string public name = "ChainTrade Coin";
    string public symbol = "CTC";
    uint public decimals = 18;

    uint public _totalSupply = 1000000000e18;

    uint public _icoSupply = 510000000e18;

    uint public _distributionSupply = 490000000e18;
    uint public _partnershipAndAdvisorsFundSupply = 100000000e18;
    uint public _researchedForFuturedStackeholderFundSupply = 160000000e18;
    uint public _bounties = 20000000e18;
    uint public _requitixCoreTeamFundSupply = 210000000e18;

    // Balances for each account
    mapping (address => uint256) balances;

    // Owner of account approves the transfer of an amount to another account
    mapping (address => mapping(address => uint256)) allowed;

    // start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // Owner of Token
    address public owner;

    // Wallet Address of Token
    address public multisig;

    // how many token units a buyer gets per wei
    uint public PRICE;

    uint public minContribAmount = 0.01 ether; // 0.01 ether

    // amount of raised money in wei
    uint256 public fundRaised;

    bool public mintingFinished = false;

    bool public tradable = false;

    bool public active = true;

    event MintFinished();
    event StartTradable();
    event PauseTradable();
    event HaltTokenAllOperation();
    event ResumeTokenAllOperation();
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    // modifier to allow only owner has full control on the function
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

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

    // Constructor
    // @notice CTCToken Contract
    // @return the transaction address
    function CTCToken(uint256 _startTime, uint256 _endTime, address _multisig, uint _tokenPrice) {
        require(_startTime >= getNow() && _endTime >= _startTime && _tokenPrice > 0 && _multisig != 0x0);

        startTime = _startTime;
        endTime = _endTime;
        multisig = _multisig;
        PRICE = _tokenPrice;

        balances[multisig] = _totalSupply;

        owner = msg.sender;
    }

    // Payable method
    // @notice Anyone can buy the tokens on tokensale by paying ether
    function () payable {
        tokensale(msg.sender);
    }

    // @notice tokensale
    // @param recipient The address of the recipient
    // @return the transaction address and send the event as Transfer
    function tokensale(address recipient) payable canMint isActive {
        require(recipient != 0x0);
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint tokens = weiAmount.mul(getPrice());

        require(_icoSupply >= tokens);

        // update state
        fundRaised = fundRaised.add(weiAmount);

        balances[multisig] = balances[multisig].sub(tokens);
        balances[recipient] = balances[recipient].add(tokens);

       _icoSupply = _icoSupply.sub(tokens);

        TokenPurchase(msg.sender, recipient, weiAmount, tokens);

        forwardFunds();
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
        return withinPeriod && nonZeroPurchase && minContribution;
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
        PRICE = _tokenPrice;
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

    // Halt or Resume all operations on contract & Crowd Sale
    function haltAllOperation(bool _active) onlyOwner {
        active = _active;
        if (active)
            ResumeTokenAllOperation();
        else
            HaltTokenAllOperation();
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

    // Token distribution to founder, develoment team, partners, charity, and bounty
    function sendPartnershipAndAdvisorsFundSupplyToken(address to, uint256 value) onlyOwner isActive {
        require (
            to != 0x0 && value > 0 && _partnershipAndAdvisorsFundSupply >= value
        );

        balances[multisig] = balances[multisig].sub(value);
        balances[to] = balances[to].add(value);
        _partnershipAndAdvisorsFundSupply = _partnershipAndAdvisorsFundSupply.sub(value);
        Transfer(multisig, to, value);
    }

    function sendResearchedForFuturedStackeholderFundSupplyToken(address to, uint256 value) onlyOwner isActive {
        require (
            to != 0x0 && value > 0 && _researchedForFuturedStackeholderFundSupply >= value
        );

        balances[multisig] = balances[multisig].sub(value);
        balances[to] = balances[to].add(value);
        _researchedForFuturedStackeholderFundSupply = _researchedForFuturedStackeholderFundSupply.sub(value);
        Transfer(multisig, to, value);
    }

    function sendBountiesToken(address to, uint256 value) onlyOwner isActive {
        require (
            to != 0x0 && value > 0 && _bounties >= value
        );

        balances[multisig] = balances[multisig].sub(value);
        balances[to] = balances[to].add(value);
        _bounties = _bounties.sub(value);
        Transfer(multisig, to, value);
    }

    function sendRequitixCoreTeamFundSupplyToken(address to, uint256 value) onlyOwner isActive {
        require (
            to != 0x0 && value > 0 && _requitixCoreTeamFundSupply >= value
        );

        balances[multisig] = balances[multisig].sub(value);
        balances[to] = balances[to].add(value);
        _requitixCoreTeamFundSupply = _requitixCoreTeamFundSupply.sub(value);
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
    function getPrice() constant returns (uint result) {
      return PRICE;
    }
}
