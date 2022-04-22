// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IWarikanV1Pool {
  /** 
    Joins Warikan Pool.
    
    One person have one share of the warikan.abi
    I'm planning to adjust shares with ERC20 in WarikanV2
   */
  function join() external;
  /** Leaves Warikan Pool */
  function leave() external;
  /** Joins Warikan Pool with EIP-2612 Permit */
  function joinWithPermit(uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
  /** 
    Commit Warikan and collect token from Pool member
    */
  function commit() external;
  /** 
    Cancel Warikan, refund token and dispose Pool
    */
  function cancel() external;
  /** Withdraw collected token to pool owner */
  function withdraw() external;
  /** Get current estimated value of token that member will pay */
  function getValueToPay(address _member) view external returns (uint256);

  /** Checks the address is in the pool */
  function isMember(address _member) view external returns (bool);
}