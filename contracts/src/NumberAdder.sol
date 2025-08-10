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


contract SimplePayroll is Ownable, ReentrancyGuard {

    // Struct to hold employee data
    struct Employee {
        uint256 salary;
        uint256 index; // To track position in the employees array for O(1) removal
        bool exists;
    }

    // Mappings and arrays
    mapping(address => Employee) public employees;
    address[] public employeeList;

    // Events
    event EmployeeAdded(address indexed employee, uint256 salary);
    event EmployeeRemoved(address indexed employee);
    event SalaryUpdated(address indexed employee, uint256 newSalary);
    event PayrollDistributed(uint256 totalAmount, uint256 employeeCount);
    event FundsReceived(address indexed from, uint256 amount);

    /**
     * @notice Allows the contract to receive ETH.
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @notice Adds a new employee or updates the salary of an existing one.
     * @param _employee The address of the employee.
     * @param _salary The monthly salary in wei.
     */
    function addOrUpdateEmployee(address _employee, uint256 _salary) external onlyOwner {
        require(_employee != address(0), "Invalid employee address");
        require(_salary > 0, "Salary must be greater than zero");

        if (employees[_employee].exists) {
            // Update existing employee's salary
            employees[_employee].salary = _salary;
            emit SalaryUpdated(_employee, _salary);
        } else {
            // Add new employee
            employees[_employee] = Employee({ salary: _salary, index: employeeList.length, exists: true });
            employeeList.push(_employee);
            emit EmployeeAdded(_employee, _salary);
        }
    }

    /**
     * @notice Removes an employee from the payroll.
     * @param _employee The address of the employee to remove.
     */
    function removeEmployee(address _employee) external onlyOwner {
        require(employees[_employee].exists, "Employee does not exist");

        // O(1) removal by swapping with the last element
        uint256 indexToRemove = employees[_employee].index;
        address lastEmployee = employeeList[employeeList.length - 1];

        // Move the last employee to the spot of the one being removed
        employeeList[indexToRemove] = lastEmployee;
        employees[lastEmployee].index = indexToRemove;

        // Remove the last element
        employeeList.pop();
        delete employees[_employee];

        emit EmployeeRemoved(_employee);
    }

    /**
     * @notice Distributes salaries to all employees.
     * @dev Requires the contract to have sufficient balance.
     */
    function distributeSalaries() external onlyOwner nonReentrant {
        uint256 totalPayroll = 0;
        uint256 employeeCount = employeeList.length;
        require(employeeCount > 0, "No employees to pay");

        for (uint i = 0; i < employeeCount; i++) {
            totalPayroll += employees[employeeList[i]].salary;
        }

        require(address(this).balance >= totalPayroll, "Insufficient funds for payroll");

        for (uint i = 0; i < employeeCount; i++) {
            address employeeAddress = employeeList[i];
            uint256 salary = employees[employeeAddress].salary;
            payable(employeeAddress).transfer(salary);
        }

        emit PayrollDistributed(totalPayroll, employeeCount);
    }

    /**
     * @notice Gets the number of employees.
     * @return The total number of employees.
     */
    function getEmployeeCount() external view returns (uint256) {
        return employeeList.length;
    }

    /**
     * @notice Allows the owner to withdraw any excess funds from the contract.
     */
    function withdrawExcessFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }
}
