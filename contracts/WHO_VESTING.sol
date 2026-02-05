// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WHO Vesting Vault
 * @dev Secure Token Locking for Team, Nodes, and Treasury.
 * "Roots must be deep for the tree to grow high."
 */
contract WHOTokenVesting is Ownable {
    using SafeERC20 for IERC20;

    event Vested(address indexed beneficiary, uint256 amount);
    event Released(address indexed beneficiary, uint256 amount);

    struct VestingSchedule {
        uint256 totalAmount;   // Total tokens allocated
        uint256 releasedAmount; // Tokens already claimed
        uint256 startTimestamp; // Vesting start
        uint256 cliffDuration;  // Cliff (seconds)
        uint256 duration;       // Total vesting duration (seconds)
        bool revocable;         // Can DAO revoke?
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) public schedules;

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    /**
     * @dev Create a Vesting Schedule
     * @param beneficiary Address of the receiver
     * @param amount Total tokens
     * @param start Unix timestamp start
     * @param cliff Seconds until first release
     * @param duration Total seconds for full vesting
     */
    function createSchedule(
        address beneficiary,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        bool revocable
    ) external onlyOwner {
        require(schedules[beneficiary].totalAmount == 0, "Schedule exists");
        require(duration > 0, "Duration > 0");
        require(amount > 0, "Amount > 0");

        // Transfer tokens to this contract (Must Approve First)
        token.safeTransferFrom(msg.sender, address(this), amount);

        schedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTimestamp: start,
            cliffDuration: cliff,
            duration: duration,
            revocable: revocable
        });

        emit Vested(beneficiary, amount);
    }

    /**
     * @dev Release vested tokens to benficiary
     */
    function release() external {
        _release(msg.sender);
    }

    function releaseFor(address beneficiary) external {
        _release(beneficiary);
    }

    function _release(address beneficiary) internal {
        VestingSchedule storage schedule = schedules[beneficiary];
        require(schedule.totalAmount > 0, "No schedule");

        uint256 vested = _vestedAmount(beneficiary);
        uint256 releasable = vested - schedule.releasedAmount;
        require(releasable > 0, "Nothing to release");

        schedule.releasedAmount += releasable;
        token.safeTransfer(beneficiary, releasable);

        emit Released(beneficiary, releasable);
    }

    /**
     * @dev Calculate vested amount based on time
     */
    function _vestedAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = schedules[beneficiary];
        if (block.timestamp < schedule.startTimestamp + schedule.cliffDuration) {
            return 0;
        } else if (block.timestamp >= schedule.startTimestamp + schedule.duration) {
            return schedule.totalAmount;
        } else {
            return (schedule.totalAmount * (block.timestamp - schedule.startTimestamp)) / schedule.duration;
        }
    }

    /**
     * @dev Emergency Revoke (If revocable)
     */
    function revoke(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = schedules[beneficiary];
        require(schedule.revocable, "Not revocable");

        uint256 vested = _vestedAmount(beneficiary);
        uint256 refund = schedule.totalAmount - vested;

        schedule.totalAmount = vested; // Cap at vested
        token.safeTransfer(owner(), refund);
    }
}
