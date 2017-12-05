pragma solidity ^0.4.18;


contract OracleContract {

    mapping (address => uint)lastPrices;
    uint public lastPriceETHUSD = 0;
    address dutchExchange = 0;

    function OracleContract(address _dutchExchange) public {
        dutchExchange = _dutchExchange;
    }

    function getETHvsTokenPrice(address tokenAddress) public
        view
        returns (uint)
    {
        // lastPrices[GNOTokenAddress] = dutchExchange.getlastPrice(GNOTokenAddress)
        require(lastPrices[tokenAddress]!=0);
        return lastPrices[tokenAddress];
    }

    function getUSDETHPrice() public
        view
        returns (uint)
    {
        // lastPricesETHUSD = calculatePricesFromOracles();
        return lastPriceETHUSD;
    }
}
