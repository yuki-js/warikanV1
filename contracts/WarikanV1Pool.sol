// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "./interfaces/IWarikanV1Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

contract WarikanPool is IWarikanV1Pool {
    uint256 immutable targetBalance;

    IERC20 immutable token;

    address immutable poolOwner;

    // member set
    address[] members;
    mapping(address => uint256) memberMapping; // member => member's index. Note that rhs is one-based-index to prevent 0.

    // state flag
    bool commited = false;
    bool cancelled = false;
    bool withdrawn = false;

    constructor(uint256 _targetBalance, address _token) {
        targetBalance = _targetBalance;
        token = IERC20(_token);
        poolOwner = msg.sender;
    }

    function join() public override {
        require(!cancelled);
        require(!commited);
        require(msg.sender != address(0));

        // Checks if the sender is already a member
        require(!isMember(msg.sender));

        // Checks if member has paying ability at that time.
        // Note: It does not guarantee that member can pay at the time commit is called. It's mere a check.
        require(token.allowance(msg.sender, address(this)) >= targetBalance);

        // Adds the sender to the pool
        addToLastMemberSet(msg.sender);
    }

    function isMember(address _member) public view override returns (bool) {
        if (cancelled || withdrawn) {
            return false;
        }
        return memberMapping[_member] != 0;
    }

    function leave() public override {
        require(!cancelled);
        require(!commited);
        require(msg.sender != address(0));

        // Checks if the sender is a member
        require(isMember(msg.sender));

        // Removes the sender from the pool
        swapPopMemberSet(msg.sender);
    }

    function joinWithPermit(
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        IERC20Permit(address(token)).permit( // runtime error if token is not IERC20Permit
            msg.sender,
            address(this),
            targetBalance,
            deadline,
            v,
            r,
            s
        );
        join();
    }

    function commit() external override onlyPoolOwner {
        require(!cancelled);
        require(!commited);
        require(msg.sender != address(0));

        // iterate members and pay
        for (uint256 i = 1; i <= members.length; i++) {
            // pay
            address m = members[i];
            token.transferFrom(m, address(this), getExactValueToPay(m));
        }
        commited = true;
    }

    function cancel() external override onlyPoolOwner {
        require(!cancelled);
        require(!withdrawn);
        if (commited) {
            // refund
            for (uint256 i = 1; i <= members.length; i++) {
                // refund
                address m = members[i];
                token.transfer(m, getExactValueToPay(m));
            }
        } else {
            // not refunded
        }
        cancelled = true;
    }

    function withdraw() external override onlyPoolOwner {
        require(commited);
        require(!cancelled);
        require(!withdrawn);

        // send to poolOwner
        token.transfer(poolOwner, targetBalance);

        withdrawn = true;
    }

    function getExactValueToPay(address _member)
        internal
        view
        returns (uint256)
    {
        require(isMember(_member));
        uint256 remainder = targetBalance % members.length;
        uint256 baseValue = targetBalance / members.length;

        if (memberMapping[_member] <= remainder) {
            return baseValue + 1;
        } else {
            return baseValue;
        }

        // then sum of all members' value to pay equals targetBalance
    }

    function getValueToPay(address _member)
        public
        view
        override
        returns (uint256)
    {
        return getExactValueToPay(_member);
    }

    function addToLastMemberSet(address _member) private {
        members.push(_member);
        memberMapping[_member] = members.length;
    }

    function swapPopMemberSet(address memberToPop) private {
        uint256 indexToPop = memberMapping[memberToPop]; // one-based index
        uint256 lastIndex = members.length; // one-based index
        address lastMember = members[lastIndex - 1];

        members[indexToPop - 1] = lastMember;
        members.pop();

        memberMapping[lastMember] = indexToPop;
        delete memberMapping[memberToPop];
    }

    modifier onlyPoolOwner() {
        require(msg.sender == poolOwner);
        _;
    }
}
