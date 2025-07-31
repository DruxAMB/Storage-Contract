// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TaskManager
 * @dev A decentralized task/todo management system with assignments and payments
 * @notice Allows users to create tasks, assign to others, mark complete, and handle payments
 */
contract TaskManager {
    
    // Enums
    enum TaskStatus { Created, Assigned, InProgress, Completed, Cancelled }
    enum TaskPriority { Low, Medium, High, Urgent }
    
    // Structs
    struct Task {
        uint256 id;
        string title;
        string description;
        address creator;
        address assignee;
        uint256 reward;
        uint256 createdAt;
        uint256 deadline;
        TaskStatus status;
        TaskPriority priority;
        bool paymentReleased;
    }
    
    struct TaskSubmission {
        uint256 taskId;
        address assignee;
        string submissionDetails;
        uint256 submittedAt;
        bool approved;
    }
    
    // State variables
    mapping(uint256 => Task) public tasks;
    mapping(uint256 => TaskSubmission) public submissions;
    mapping(address => uint256[]) public userCreatedTasks;
    mapping(address => uint256[]) public userAssignedTasks;
    mapping(uint256 => uint256) public taskSubmissions; // taskId => submissionId
    
    uint256 public taskCount;
    uint256 public submissionCount;
    uint256 public totalRewardsLocked;
    
    // Platform fee (in basis points, 200 = 2%)
    uint256 public platformFee = 200;
    address payable public owner;
    
    // Events
    event TaskCreated(
        uint256 indexed taskId,
        address indexed creator,
        string title,
        uint256 reward,
        uint256 deadline
    );
    
    event TaskAssigned(
        uint256 indexed taskId,
        address indexed assignee,
        uint256 timestamp
    );
    
    event TaskStarted(
        uint256 indexed taskId,
        address indexed assignee,
        uint256 timestamp
    );
    
    event TaskSubmitted(
        uint256 indexed taskId,
        uint256 indexed submissionId,
        address indexed assignee,
        uint256 timestamp
    );
    
    event TaskCompleted(
        uint256 indexed taskId,
        address indexed assignee,
        uint256 reward,
        uint256 timestamp
    );
    
    event TaskCancelled(
        uint256 indexed taskId,
        address indexed creator,
        uint256 timestamp
    );
    
    event PaymentReleased(
        uint256 indexed taskId,
        address indexed assignee,
        uint256 amount,
        uint256 platformFee
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier validTask(uint256 taskId) {
        require(taskId < taskCount, "Task does not exist");
        _;
    }
    
    modifier onlyCreator(uint256 taskId) {
        require(msg.sender == tasks[taskId].creator, "Only creator can perform this action");
        _;
    }
    
    modifier onlyAssignee(uint256 taskId) {
        require(msg.sender == tasks[taskId].assignee, "Only assignee can perform this action");
        _;
    }
    
    constructor() {
        owner = payable(msg.sender);
    }
    
    /**
     * @dev Create a new task with optional reward
     * @param title Task title
     * @param description Task description
     * @param deadline Task deadline (timestamp)
     * @param priority Task priority (0=Low, 1=Medium, 2=High, 3=Urgent)
     * @return taskId The ID of the created task
     */
    function createTask(
        string memory title,
        string memory description,
        uint256 deadline,
        TaskPriority priority
    ) external payable returns (uint256 taskId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(deadline > block.timestamp, "Deadline must be in the future");
        
        taskId = taskCount++;
        uint256 reward = msg.value;
        
        tasks[taskId] = Task({
            id: taskId,
            title: title,
            description: description,
            creator: msg.sender,
            assignee: address(0),
            reward: reward,
            createdAt: block.timestamp,
            deadline: deadline,
            status: TaskStatus.Created,
            priority: priority,
            paymentReleased: false
        });
        
        if (reward > 0) {
            totalRewardsLocked += reward;
        }
        
        userCreatedTasks[msg.sender].push(taskId);
        
        emit TaskCreated(taskId, msg.sender, title, reward, deadline);
    }
    
    /**
     * @dev Assign a task to someone (creator only)
     * @param taskId Task ID to assign
     * @param assignee Address to assign task to
     */
    function assignTask(uint256 taskId, address assignee) 
        external 
        validTask(taskId) 
        onlyCreator(taskId) 
    {
        require(assignee != address(0), "Invalid assignee address");
        require(tasks[taskId].status == TaskStatus.Created, "Task cannot be assigned");
        require(block.timestamp <= tasks[taskId].deadline, "Task deadline has passed");
        
        Task storage task = tasks[taskId];
        task.assignee = assignee;
        task.status = TaskStatus.Assigned;
        
        userAssignedTasks[assignee].push(taskId);
        
        emit TaskAssigned(taskId, assignee, block.timestamp);
    }
    
    /**
     * @dev Self-assign an available task
     * @param taskId Task ID to self-assign
     */
    function selfAssignTask(uint256 taskId) 
        external 
        validTask(taskId) 
    {
        require(tasks[taskId].status == TaskStatus.Created, "Task not available for assignment");
        require(block.timestamp <= tasks[taskId].deadline, "Task deadline has passed");
        require(msg.sender != tasks[taskId].creator, "Creator cannot self-assign");
        
        Task storage task = tasks[taskId];
        task.assignee = msg.sender;
        task.status = TaskStatus.Assigned;
        
        userAssignedTasks[msg.sender].push(taskId);
        
        emit TaskAssigned(taskId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Start working on an assigned task
     * @param taskId Task ID to start
     */
    function startTask(uint256 taskId) 
        external 
        validTask(taskId) 
        onlyAssignee(taskId) 
    {
        require(tasks[taskId].status == TaskStatus.Assigned, "Task not in assigned status");
        require(block.timestamp <= tasks[taskId].deadline, "Task deadline has passed");
        
        tasks[taskId].status = TaskStatus.InProgress;
        
        emit TaskStarted(taskId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Submit completed task for review
     * @param taskId Task ID to submit
     * @param submissionDetails Details of the completed work
     */
    function submitTask(uint256 taskId, string memory submissionDetails) 
        external 
        validTask(taskId) 
        onlyAssignee(taskId) 
    {
        require(
            tasks[taskId].status == TaskStatus.InProgress || 
            tasks[taskId].status == TaskStatus.Assigned, 
            "Task not in progress"
        );
        require(bytes(submissionDetails).length > 0, "Submission details cannot be empty");
        
        uint256 submissionId = submissionCount++;
        
        submissions[submissionId] = TaskSubmission({
            taskId: taskId,
            assignee: msg.sender,
            submissionDetails: submissionDetails,
            submittedAt: block.timestamp,
            approved: false
        });
        
        taskSubmissions[taskId] = submissionId;
        tasks[taskId].status = TaskStatus.Completed;
        
        emit TaskSubmitted(taskId, submissionId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Approve task completion and release payment
     * @param taskId Task ID to approve
     */
    function approveTask(uint256 taskId) 
        external 
        validTask(taskId) 
        onlyCreator(taskId) 
    {
        require(tasks[taskId].status == TaskStatus.Completed, "Task not completed");
        require(!tasks[taskId].paymentReleased, "Payment already released");
        
        Task storage task = tasks[taskId];
        uint256 submissionId = taskSubmissions[taskId];
        
        submissions[submissionId].approved = true;
        task.paymentReleased = true;
        
        // Release payment if there's a reward
        if (task.reward > 0) {
            uint256 feeAmount = (task.reward * platformFee) / 10000;
            uint256 assigneeAmount = task.reward - feeAmount;
            
            totalRewardsLocked -= task.reward;
            
            if (feeAmount > 0) {
                owner.transfer(feeAmount);
            }
            payable(task.assignee).transfer(assigneeAmount);
            
            emit PaymentReleased(taskId, task.assignee, assigneeAmount, feeAmount);
        }
        
        emit TaskCompleted(taskId, task.assignee, task.reward, block.timestamp);
    }
    
    /**
     * @dev Cancel a task and refund reward (creator only)
     * @param taskId Task ID to cancel
     */
    function cancelTask(uint256 taskId) 
        external 
        validTask(taskId) 
        onlyCreator(taskId) 
    {
        require(
            tasks[taskId].status != TaskStatus.Completed && 
            tasks[taskId].status != TaskStatus.Cancelled,
            "Cannot cancel completed or already cancelled task"
        );
        
        Task storage task = tasks[taskId];
        task.status = TaskStatus.Cancelled;
        
        // Refund reward to creator
        if (task.reward > 0 && !task.paymentReleased) {
            totalRewardsLocked -= task.reward;
            payable(task.creator).transfer(task.reward);
        }
        
        emit TaskCancelled(taskId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Get task information
     * @param taskId Task ID
     * @return title Task title
     * @return description Task description
     * @return creator Task creator address
     * @return assignee Task assignee address
     * @return reward Task reward amount
     * @return deadline Task deadline
     * @return status Task status
     * @return priority Task priority
     */
    function getTask(uint256 taskId) 
        external 
        view 
        validTask(taskId) 
        returns (
            string memory title,
            string memory description,
            address creator,
            address assignee,
            uint256 reward,
            uint256 deadline,
            TaskStatus status,
            TaskPriority priority
        ) 
    {
        Task storage task = tasks[taskId];
        return (
            task.title,
            task.description,
            task.creator,
            task.assignee,
            task.reward,
            task.deadline,
            task.status,
            task.priority
        );
    }
    
    /**
     * @dev Get task submission details
     * @param taskId Task ID
     * @return submissionDetails Submission details
     * @return submittedAt Submission timestamp
     * @return approved Whether submission is approved
     */
    function getTaskSubmission(uint256 taskId) 
        external 
        view 
        validTask(taskId) 
        returns (
            string memory submissionDetails,
            uint256 submittedAt,
            bool approved
        ) 
    {
        uint256 submissionId = taskSubmissions[taskId];
        if (submissionId == 0 && submissions[0].taskId != taskId) {
            return ("", 0, false);
        }
        
        TaskSubmission storage submission = submissions[submissionId];
        return (
            submission.submissionDetails,
            submission.submittedAt,
            submission.approved
        );
    }
    
    /**
     * @dev Get tasks created by a user
     * @param user User address
     * @return taskIds Array of task IDs created by user
     */
    function getUserCreatedTasks(address user) 
        external 
        view 
        returns (uint256[] memory taskIds) 
    {
        return userCreatedTasks[user];
    }
    
    /**
     * @dev Get tasks assigned to a user
     * @param user User address
     * @return taskIds Array of task IDs assigned to user
     */
    function getUserAssignedTasks(address user) 
        external 
        view 
        returns (uint256[] memory taskIds) 
    {
        return userAssignedTasks[user];
    }
    
    /**
     * @dev Get available tasks (not assigned, not expired)
     * @param limit Maximum number of tasks to return
     * @return taskIds Array of available task IDs
     */
    function getAvailableTasks(uint256 limit) 
        external 
        view 
        returns (uint256[] memory taskIds) 
    {
        uint256 availableCount = 0;
        
        // Count available tasks
        for (uint256 i = 0; i < taskCount; i++) {
            if (tasks[i].status == TaskStatus.Created && 
                block.timestamp <= tasks[i].deadline) {
                availableCount++;
            }
        }
        
        if (limit > availableCount) {
            limit = availableCount;
        }
        
        taskIds = new uint256[](limit);
        uint256 index = 0;
        
        for (uint256 i = 0; i < taskCount && index < limit; i++) {
            if (tasks[i].status == TaskStatus.Created && 
                block.timestamp <= tasks[i].deadline) {
                taskIds[index] = i;
                index++;
            }
        }
    }
    
    /**
     * @dev Get tasks by status
     * @param status Task status to filter by
     * @param limit Maximum number of tasks to return
     * @return taskIds Array of task IDs with specified status
     */
    function getTasksByStatus(TaskStatus status, uint256 limit) 
        external 
        view 
        returns (uint256[] memory taskIds) 
    {
        uint256 statusCount = 0;
        
        // Count tasks with status
        for (uint256 i = 0; i < taskCount; i++) {
            if (tasks[i].status == status) {
                statusCount++;
            }
        }
        
        if (limit > statusCount) {
            limit = statusCount;
        }
        
        taskIds = new uint256[](limit);
        uint256 index = 0;
        
        for (uint256 i = 0; i < taskCount && index < limit; i++) {
            if (tasks[i].status == status) {
                taskIds[index] = i;
                index++;
            }
        }
    }
    
    /**
     * @dev Get total number of tasks
     * @return count Total task count
     */
    function getTotalTasks() external view returns (uint256 count) {
        return taskCount;
    }
    
    /**
     * @dev Get platform statistics
     * @return totalTasks Total tasks created
     * @return totalSubmissions Total submissions made
     * @return totalRewardsAmount Total rewards locked
     * @return availableTasksCount Number of available tasks
     */
    function getPlatformStats() 
        external 
        view 
        returns (
            uint256 totalTasks,
            uint256 totalSubmissions,
            uint256 totalRewardsAmount,
            uint256 availableTasksCount
        ) 
    {
        uint256 availableCount = 0;
        for (uint256 i = 0; i < taskCount; i++) {
            if (tasks[i].status == TaskStatus.Created && 
                block.timestamp <= tasks[i].deadline) {
                availableCount++;
            }
        }
        
        return (taskCount, submissionCount, totalRewardsLocked, availableCount);
    }
    
    /**
     * @dev Update platform fee (owner only)
     * @param newFee New platform fee in basis points
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Platform fee too high"); // Max 10%
        platformFee = newFee;
    }
    
    /**
     * @dev Emergency withdraw (owner only) - for stuck funds
     */
    function emergencyWithdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }
}
