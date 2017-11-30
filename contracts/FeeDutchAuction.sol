pragma solidity ^0.4.16;



contract FeeDutchAuction{
 address public GNOTokenAddress;
  function FeeDutchAuction(address _GNOTokenAddress) public{
    GNOTokenAddress=_GNOTokenAddress;
  }
}
