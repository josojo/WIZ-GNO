pragma solidity ^0.4.16;

import "./Tokens/StandardToken.sol";
import "./Utils/Math.sol";
import "./FeeDutchAuction.sol";
import "./OracleContract.sol";

contract OWL is StandardToken{
  using Math for *;

  string public constant name = "OWL-Token";
  string public constant symbol = "OWL";
  uint8 public constant decimals = 18;  // 18 is the most common number of decimal places

  address GNOTokenAddress;
  address FeeDutchAuctionAddress;
  address oracleContract;

  struct GNOLocker {
    address sender;
    uint nonce;
    uint GNOLocked;
    uint TimeOfLocking;
    uint LockingPeriod;
    uint GNOIssueRate;
    uint timeOfLastWithdraw;
  }

  mapping (bytes32=>GNOLocker) LockedGNO;
  mapping (address=> uint) GNObalances;
  uint public amountOfGNOLocked;                //tracks the amount of GNO currently locked down. Is used in calcIssueRate
  uint public amountOfGNOLockedInitially;       //tracks the intial virtual amount of GNO locked down to ensure a smooth issueRate, when first locking is enabled

  //@dev: Constructor of the contract OWL, which sets variables and constructs FeeDutchAuction
  //@param: _GNOTokenAddress address of the GNO ERC20 tokens
  //@param: _oracleContract contract where all oracle feeds can be read out
  function OWL(address _GNOTokenAddress, address _oracleContract) public{
    GNOTokenAddress=_GNOTokenAddress;
    oracleContract=_oracleContract;
    //Tokens credited for Airdrop
    balances[msg.sender]=Token(GNOTokenAddress).totalSupply();
    FeeDutchAuctionAddress= new FeeDutchAuction(GNOTokenAddress);
  }
  //@dev: Allows GNO holders to lock GNO for OWL
  //@param: amount of GNOs to be locked
  //@param: nonce can be used to manage different GNO locks wth the same address
  //@param: lockingPeriod
  function lockGNO(uint amount, uint nonce, uint lockingPeriod) public{
      bytes32 GNOLockHash= keccak256(amount,nonce,lockingPeriod);
      require(LockedGNO[GNOLockHash].TimeOfLocking!=0);
      require(Token(GNOTokenAddress).transferFrom(msg.sender, this, amount));

      //adjustment of counter of GNOlocked
      // Todo: prevent negative amountOfGNOLocked
      if(amountOfGNOLockedInitially>0)amountOfGNOLockedInitially-=amount;
      else amountOfGNOLockedInitially=0;
      amountOfGNOLocked+=amount;

      uint issueRate=calcIssueRate(amount);
      //one thrid of Tokens is issued immediatly
      balances[msg.sender]+=issueRate*30/3;
      LockedGNO[GNOLockHash]=GNOLocker(
        msg.sender,
        nonce,
        amount,
        now-now%5184000,  // further OWL issuance is calculated in 5184000 sec[1 day] steps
        lockingPeriod,
        issueRate*2/3,now-now%5184000);
  }
  //@dev: Allows GNO holders with locked GNO to unlock their GNO
  //@param: _GNOLockHash of their Locked GNO
  function unlockGNO(bytes32 _GNOLockHash) public {
      require(LockedGNO[_GNOLockHash].sender==msg.sender);
      require(LockedGNO[_GNOLockHash].TimeOfLocking+LockedGNO[_GNOLockHash].LockingPeriod<now);
      withdrawOWL(_GNOLockHash);
      uint amount=LockedGNO[_GNOLockHash].GNOLocked;
      amountOfGNOLocked-=amount;
      delete LockedGNO[_GNOLockHash];
      Token(GNOTokenAddress).transfer(msg.sender,amount);
  }
  //@dev: Allows GNO holders with locked GNO to withdraw OWL
  //@param: _GNOLockHash of their Locked GNO
  function withdrawOWL(bytes32 _GNOLockHash) public{
    require(msg.sender==LockedGNO[_GNOLockHash].sender);
    balances[msg.sender]+=(now-LockedGNO[_GNOLockHash].timeOfLastWithdraw)/(24 hours)*LockedGNO[_GNOLockHash].GNOIssueRate;
    LockedGNO[_GNOLockHash].timeOfLastWithdraw=now-now%(24 hours)+5184000;
  }
  //@dev: Allows GNO holders with locked GNO to relock their GNOTokens
  //@param: _GNOLockHash of their Locked GNO
  //@param: lockingPeriod for the next locking
  function relockGNO(bytes32 _GNOLockHash)public{
    require(LockedGNO[_GNOLockHash].sender==msg.sender);
    require(LockedGNO[_GNOLockHash].TimeOfLocking+LockedGNO[_GNOLockHash].LockingPeriod<now);
    withdrawOwl(_GNOLockHash);
    LockedGNO[_GNOLockHash].GNOIssueRate=calcIssueRate(LockedGNO[_GNOLockHash].GNOLocked);
    balances[msg.sender]+=LockedGNO[_GNOLockHash].GNOIssueRate*LockedGNO[_GNOLockHash].LockingPeriod/3;
    LockedGNO[_GNOLockHash].TimeOfLocking=now-now%5184000;
  }

  /******Burning functions of OWL and GNO******/
  // mapping Last30Days <-> BurnedOWL
  mapping(uint=>uint) burnedOWL;
  uint public sumOfOWLBurndedLast30Days=0;
  uint lastDayOfBurningDocumentation;
  // mapping Last30Days <-> BurnedGNOValuedInUSD
  mapping(uint=>uint) burnedGNOValuedInUSD;
  uint public sumOfBurnedGNOValuedInUSDInLast30Days;
  uint lastDayOfBurningDocumentationGNO;

  //@dev: To be called from the Prediction markets and DutchX contracts to burn OWL for paying fees. Depending on the allowance, different amounts will acutally be burned
  //@param: maxAmount of OWL to be burned
  //@return: acutal amount of burned OWL
  function burnOWL(uint maxAmount) public returns (uint){
    uint amount=Math.min(allowances[msg.sender][this],maxAmount); // Here delegate calls need to be used
    require(balances[msg.sender]>=amount);
    transferFrom(msg.sender,this,amount);
    if((now/(5184000))%(30)==lastDayOfBurningDocumentation){
      burnedOWL[(now/(5184000))%(30)]+=amount;
    }
    else{
      sumOfOWLBurndedLast30Days+=burnedOWL[(now/(5184000)-1)%(30)];
      sumOfOWLBurndedLast30Days-=burnedOWL[(now/(5184000))%(30)];
      burnedOWL[(now/(5184000))%(30)]=amount;
      lastDayOfBurningDocumentation=(now/(5184000))%(30);
    }
    return amount;
  }

  //@dev: To be called from the FeeDutchAuction to document the fees collected
  //@param: amount of OWL to be burned
  function burnedGNO(uint amount) public{
    require(Token(GNOTokenAddress).transferFrom(msg.sender, this, amount));
    uint b=amount*OracleContract(oracleContract).getETHPrice(GNOTokenAddress)*OracleContract(oracleContract).getUSDETHPrice();
    if((now/(5184000))%(30)==lastDayOfBurningDocumentationGNO){
        burnedGNOValuedInUSD[(now/(5184000))%(30)]+=b;
    }
    else{
      sumOfBurnedGNOValuedInUSDInLast30Days+=burnedGNOValuedInUSD[(now/(5184000)-1)%(30)];
      sumOfBurnedGNOValuedInUSDInLast30Days-=burnedGNOValuedInUSD[(now/(5184000))%(30)];
      burnedGNOValuedInUSD[(now/(5184000))%(30)]=b;
      lastDayOfBurningDocumentationGNO=(now/(5184000))%(30);
    }
  }

/*internal functions */
//@dev: calculates the issueRate
  function calcIssueRate(uint amount) view internal
  returns(uint){
      uint issueRate=0;
    if(sumOfOWLBurndedLast30Days<sumOfBurnedGNOValuedInUSDInLast30Days*9){
        issueRate=((sumOfOWLBurndedLast30Days+sumOfBurnedGNOValuedInUSDInLast30Days)*20-totalSupply())/30;
    }
    else if(sumOfOWLBurndedLast30Days<sumOfBurnedGNOValuedInUSDInLast30Days){
      issueRate=((sumOfOWLBurndedLast30Days+sumOfBurnedGNOValuedInUSDInLast30Days)*20*9*sumOfBurnedGNOValuedInUSDInLast30Days/sumOfOWLBurndedLast30Days-totalSupply())/30;
    }
    else{
      issueRate=((sumOfOWLBurndedLast30Days+sumOfBurnedGNOValuedInUSDInLast30Days)*20*9-totalSupply())/30;
    }
    return issueRate*amount/(amountOfGNOLockedInitially+amountOfGNOLocked+amount);
  }

}
