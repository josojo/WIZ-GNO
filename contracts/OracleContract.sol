pragma solidity ^0.4.16;

contract OracleContract{

  mapping (address => uint)lastPrices;
  uint public lastPriceETHUSD=0;
  address DutchExchange=0;

  function OracleContract(address _DutchExchange) public{
    DutchExchange=_DutchExchange;
  }

  function getETHPrice(address GNOTokenAddress) public
  returns (uint)
  {
    // lastPrices[GNOTokenAddress]=DutchExchange.getlastPrice(GNOTokenAddress)
    require(lastPrices[GNOTokenAddress]!=0);
    return lastPrices[GNOTokenAddress];
  }
  function getUSDETHPrice() public
  returns (uint){
      // lastPricesETHUSD=calculatePricesFromOracles
    return lastPriceETHUSD;
  }
}