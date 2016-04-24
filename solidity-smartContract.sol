/* CENTRALIZED ADMINISTRATOR */
contract owned {
    address public owner;
    
    function owned(){
        owner = msg.sender;
    }
    
    modifier onlyOwner{
        if(msg.sender != owner) throw;
    }
    
    function transferOwnership(address newOwner) onlyOwner{
        owner = newOwner;
    }
    
}

contract MyToken is owned{    
    
    /*Events*/
    event Transfer(address indexed from, address indexed to, uint256 value);
    event FrozenFunds(address target, bool frozen);
    
    /*Variables declaration*/
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public sellPrice;
    uint256 public buyPrice;
    uint minBalanceForAccounts;
    bool senderPaysFees;
    uint currentChallenge = 1;  // Compute the cubic root of the number ?
    bytes32 public currentChallengePoW; // The coin starts with a challenge
    uint public timeOfLastProof;    // Variable to keep track when last reward was given
    uint public difficulty = 10**32;    // Difficulty starts reasonably low

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => bool) public approvedAccount;
    
    /* Initializes contract with initial supply tokens to the creator of the contract */
    function myToken(
        uint256 initialSupply, 
        string tokenName, 
        uint8 decimalUnits, 
        string tokenSymbol,
        address centralMinter
        ) {
            if(centralMinter != 0) owner = msg.sender;
            balanceOf[msg.sender] = initialSupply;  // Give the creator all initial tokens                    
            totalSupply = initialSupply;            // Update total supply
            name = tokenName;                       // Set the name for display purposes     
            symbol = tokenSymbol;                   // Set the symbol for display purposes    
            decimals = decimalUnits;                // Amount of decimals for display purposes        
            senderPaysFees = true;
            timeOfLastProof = now;                  // So that the difficulty adjustment does not go crazy
        }    
    
    /* Send coins */
    function transfer(address _to, uint256 _value) {
        /* Check if sender has balance and for overflows */
        if (balanceOf[msg.sender] < _value || balanceOf[_to] + _value < balanceOf[_to])
            throw;
            
        /* Message sender's account is frozen*/
        if(approvedAccount[msg.sender]) throw;
        
        if(senderPaysFees){
            /* Sell tokens to have enough funds to process the transaction */
            if(msg.sender.balance<minBalanceForAccounts)
                sell((minBalanceForAccounts-msg.sender.balance)/sellPrice);
        }else{
            /* ?! */
            /* Send coins to receiver if he has not enough coins to pay for the transaction */
            /* ?! */
            if(_to.balance<minBalanceForAccounts)
                _to.send(sell((minBalanceForAccounts-_to.balance)/sellPrice));
        }

        /* Add and subtract new balances */
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value; 
        
        /* Notifiy anyone listening that this transfer took place */
        Transfer(msg.sender, _to, _value);
        
    }
    
    /* CENTRAL MINT */
    function mintToken(address target, uint256 mintedAmount) onlyOwner {
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, owner, mintedAmount);
        Transfer(owner, target, mintedAmount);
    }
    
    /* FREEZING OF ASSETS */
    function freezeAccount(address target, bool freeze) onlyOwner{
        approvedAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }
    
    /* AUTOMATIC SELLING AND BUYING  - make the token's value be backed by ether (or other tokens) */
    
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    
    function buy() returns (uint amount){
        
        // Calculates the amount
        amount = msg.value / buyPrice;
        
        // Check if it has enough to sell
        if(balanceOf[this] < amount) throw;  
        
        // Update balances and execute event reflecting the change
        balanceOf[msg.sender] += amount;
        balanceOf[this] -= amount;
        Transfer(this, msg.sender, amount);
        
        return amount;
    }
    /*One ether is 1000000000000000000 wei. 
    So when setting prices for your token in ether, add 18 zeros at the end.*/
    function sell(uint amount) returns (uint revenue){
        
        // Checks if the sender has enough to sell
        if(balanceOf[msg.sender] < amount) throw;
        
        // Update balances and make transfer
        balanceOf[this] += amount;
        balanceOf[msg.sender] -= amount;
        
        // Calculate the revenue and send it to the seller
        revenue = amount * sellPrice;
        msg.sender.send(revenue);
        Transfer(msg.sender, this, amount);
        return revenue;
    }
    
    function setMinBalance(uint minimumBalanceInFinney) onlyOwner {
     minBalanceForAccounts = minimumBalanceInFinney * 1 finney; /*1 finney (0.001 ether)*/
    }
    
    /* PROOF OF WORK */
    /* Anyone who finds a block on ethereum would also get a reward from your coin,
    given that anyone calls the reward function on that block. */
    function giveBlockReward(){
        balanceOf[block.coinbase] += 1;
    }
    
    /* Math Challenge - It's also possible to add a mathematical formula, so that anyone who 
    can do math can win a reward. On this next example you have to calculate
    the cubic root of the current challenge gets a point and the right to 
    set the next challenge: */
    function rewardMathGeniuses(uint answerToCurrentChallenge, uint nextChallenge){
        if(answerToCurrentChallenge**3 != currentChallenge) throw;  // If answer is wrong, continue
        balanceOf[msg.sender] += 1; // Reward the winner
        currentChallenge = nextChallenge;   // Update the challenge
    }
    
    /* Proof of work */
    function proofOfWork(uint nonce){
        bytes8 n = bytes8(sha3(nonce,currentChallengePoW));    // Generate hash based on input
        if (n < bytes8(difficulty)) throw;  // Check if it's under the difficulty
        
        uint timeSinceLastProof = (now - timeOfLastProof);
        if(timeSinceLastProof < 5 seconds) throw;   // Reward not given too quickly
        balanceOf[msg.sender] += timeSinceLastProof / 60 seconds;   // Reward grows by the minute
        
        difficulty = difficulty * 10 minutes / timeSinceLastProof + 1;  // Adjusts the difficulty
        
        timeOfLastProof = now;  // Reset the counter
        
        // Save a hash that will be used as the next proof
        currentChallengePoW = sha3(nonce, currentChallenge, block.blockhash(block.number-1));
    }
    
    
}