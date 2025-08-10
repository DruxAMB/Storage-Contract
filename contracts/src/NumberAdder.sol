// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title NumberAdder
 * @dev A simple contract to demonstrate state changes by adding numbers.
 * @notice You can add numbers to a running total and retrieve the current sum.
 */
contract NumberAdder {

    // The current sum, publicly visible
    uint256 public currentSum;

    // Event to log when a number is added
    event NumberAdded(uint256 number, uint256 newSum);
    event SumReset();

    /**
     * @notice Adds a number to the running total.
     * @param _number The number to add.
     */
    function add(uint256 _number) external {
        currentSum += _number;
        emit NumberAdded(_number, currentSum);
    }

    /**
     * @notice Resets the running total back to zero.
     */
    function reset() external {
        currentSum = 0;
        emit SumReset();
    }

    /**
     * @notice A pure function to add two numbers without changing state.
     * @param _a The first number.
     * @param _b The second number.
     * @return The sum of _a and _b.
     */
    function addTwoNumbers(uint256 _a, uint256 _b) external pure returns (uint256) {
        return _a + _b;
    }
}


