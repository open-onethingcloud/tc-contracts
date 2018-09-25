pragma solidity ^0.4.24;

contract Ownable {
  address public _owner;

  constructor(address owner) public {
    _owner = owner;
  }

  modifier onlyOwner() {
    require(msg.sender == _owner);
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    _owner = newOwner;
  }
}
