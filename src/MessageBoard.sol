// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MessageBoard
 * @dev A decentralized message board for posting and reading public messages
 * @notice Users can post messages, reply to others, and interact in a social way
 */
contract MessageBoard {
    // Structs
    struct Message {
        uint256 id;
        address author;
        string content;
        uint256 timestamp;
        uint256 likes;
        uint256 replyCount;
        uint256 parentId; // 0 if it's a main post, otherwise ID of parent message
        bool isReply;
    }

    // State variables
    mapping(uint256 => Message) public messages;
    mapping(uint256 => mapping(address => bool)) public hasLiked;
    mapping(address => uint256[]) public userMessages;
    mapping(address => string) public userNicknames;
    mapping(uint256 => uint256[]) public messageReplies;
    
    uint256 public messageCount;
    uint256 public totalUsers;
    address public owner;
    string public boardName;
    bool public isActive;
    
    // Events
    event MessagePosted(
        uint256 indexed messageId,
        address indexed author,
        string content,
        uint256 timestamp,
        bool isReply,
        uint256 parentId
    );
    event MessageLiked(uint256 indexed messageId, address indexed liker, uint256 totalLikes);
    event NicknameSet(address indexed user, string nickname);
    event BoardStatusChanged(bool isActive, address changedBy);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier boardActive() {
        require(isActive, "Message board is currently inactive");
        _;
    }
    
    modifier validMessage(string memory content) {
        require(bytes(content).length > 0, "Message cannot be empty");
        require(bytes(content).length <= 500, "Message too long (max 500 characters)");
        _;
    }

    /**
     * @dev Constructor sets board name and owner
     * @param _boardName Name of the message board
     */
    constructor(string memory _boardName) {
        require(bytes(_boardName).length > 0, "Board name cannot be empty");
        owner = msg.sender;
        boardName = _boardName;
        messageCount = 0;
        totalUsers = 0;
        isActive = true;
    }

    /**
     * @dev Post a new message to the board
     * @param content Message content
     */
    function postMessage(string memory content) 
        external 
        boardActive 
        validMessage(content) 
    {
        // If this is user's first message, increment user count
        if (userMessages[msg.sender].length == 0) {
            totalUsers++;
        }

        uint256 messageId = messageCount++;
        
        messages[messageId] = Message({
            id: messageId,
            author: msg.sender,
            content: content,
            timestamp: block.timestamp,
            likes: 0,
            replyCount: 0,
            parentId: 0,
            isReply: false
        });

        userMessages[msg.sender].push(messageId);

        emit MessagePosted(messageId, msg.sender, content, block.timestamp, false, 0);
    }

    /**
     * @dev Reply to an existing message
     * @param parentId ID of the message to reply to
     * @param content Reply content
     */
    function replyToMessage(uint256 parentId, string memory content) 
        external 
        boardActive 
        validMessage(content) 
    {
        require(parentId < messageCount, "Parent message does not exist");
        
        // If this is user's first message, increment user count
        if (userMessages[msg.sender].length == 0) {
            totalUsers++;
        }

        uint256 messageId = messageCount++;
        
        messages[messageId] = Message({
            id: messageId,
            author: msg.sender,
            content: content,
            timestamp: block.timestamp,
            likes: 0,
            replyCount: 0,
            parentId: parentId,
            isReply: true
        });

        userMessages[msg.sender].push(messageId);
        messageReplies[parentId].push(messageId);
        messages[parentId].replyCount++;

        emit MessagePosted(messageId, msg.sender, content, block.timestamp, true, parentId);
    }

    /**
     * @dev Like a message
     * @param messageId ID of the message to like
     */
    function likeMessage(uint256 messageId) external boardActive {
        require(messageId < messageCount, "Message does not exist");
        require(!hasLiked[messageId][msg.sender], "Already liked this message");
        require(messages[messageId].author != msg.sender, "Cannot like your own message");

        hasLiked[messageId][msg.sender] = true;
        messages[messageId].likes++;

        emit MessageLiked(messageId, msg.sender, messages[messageId].likes);
    }

    /**
     * @dev Set a nickname for the caller
     * @param nickname User's display name
     */
    function setNickname(string memory nickname) external {
        require(bytes(nickname).length > 0, "Nickname cannot be empty");
        require(bytes(nickname).length <= 50, "Nickname too long (max 50 characters)");
        
        userNicknames[msg.sender] = nickname;
        emit NicknameSet(msg.sender, nickname);
    }

    /**
     * @dev Get a message by ID
     * @param messageId Message ID
     * @return id Message ID
     * @return author Author address
     * @return content Message content
     * @return timestamp When posted
     * @return likes Number of likes
     * @return replyCount Number of replies
     * @return parentId Parent message ID (0 if main post)
     * @return isReply Whether this is a reply
     */
    function getMessage(uint256 messageId) 
        external 
        view 
        returns (
            uint256 id,
            address author,
            string memory content,
            uint256 timestamp,
            uint256 likes,
            uint256 replyCount,
            uint256 parentId,
            bool isReply
        ) 
    {
        require(messageId < messageCount, "Message does not exist");
        Message memory msg = messages[messageId];
        return (
            msg.id,
            msg.author,
            msg.content,
            msg.timestamp,
            msg.likes,
            msg.replyCount,
            msg.parentId,
            msg.isReply
        );
    }

    /**
     * @dev Get recent messages (last N messages)
     * @param count Number of recent messages to return
     * @return messageIds Array of recent message IDs
     */
    function getRecentMessages(uint256 count) 
        external 
        view 
        returns (uint256[] memory messageIds) 
    {
        if (messageCount == 0) {
            return new uint256[](0);
        }

        uint256 returnCount = count > messageCount ? messageCount : count;
        messageIds = new uint256[](returnCount);
        
        uint256 startIndex = messageCount - returnCount;
        for (uint256 i = 0; i < returnCount; i++) {
            messageIds[i] = startIndex + i;
        }
    }

    /**
     * @dev Get replies to a specific message
     * @param messageId Parent message ID
     * @return replyIds Array of reply message IDs
     */
    function getReplies(uint256 messageId) 
        external 
        view 
        returns (uint256[] memory replyIds) 
    {
        require(messageId < messageCount, "Message does not exist");
        return messageReplies[messageId];
    }

    /**
     * @dev Get all messages by a specific user
     * @param user User address
     * @return messageIds Array of message IDs posted by user
     */
    function getUserMessages(address user) 
        external 
        view 
        returns (uint256[] memory messageIds) 
    {
        return userMessages[user];
    }

    /**
     * @dev Get user's nickname
     * @param user User address
     * @return nickname User's display name or empty string if not set
     */
    function getNickname(address user) 
        external 
        view 
        returns (string memory nickname) 
    {
        return userNicknames[user];
    }

    /**
     * @dev Check if user has liked a message
     * @param messageId Message ID
     * @param user User address
     * @return hasUserLiked Whether user has liked the message
     */
    function hasUserLiked(uint256 messageId, address user) 
        external 
        view 
        returns (bool hasUserLiked) 
    {
        require(messageId < messageCount, "Message does not exist");
        return hasLiked[messageId][user];
    }

    /**
     * @dev Get board statistics
     * @return name Board name
     * @return totalMessages Total number of messages
     * @return totalBoardUsers Total number of users who posted
     * @return active Whether board is active
     * @return boardOwner Owner address
     */
    function getBoardInfo() 
        external 
        view 
        returns (
            string memory name,
            uint256 totalMessages,
            uint256 totalBoardUsers,
            bool active,
            address boardOwner
        ) 
    {
        return (boardName, messageCount, totalUsers, isActive, owner);
    }

    /**
     * @dev Get user statistics
     * @param user User address
     * @return messageCount Number of messages posted by user
     * @return nickname User's display name
     * @return firstPostTime Timestamp of first post (0 if no posts)
     */
    function getUserStats(address user) 
        external 
        view 
        returns (
            uint256 userMessageCount,
            string memory nickname,
            uint256 firstPostTime
        ) 
    {
        uint256[] memory userMsgs = userMessages[user];
        uint256 firstTime = 0;
        
        if (userMsgs.length > 0) {
            firstTime = messages[userMsgs[0]].timestamp;
        }
        
        return (userMsgs.length, userNicknames[user], firstTime);
    }

    /**
     * @dev Toggle board active status (owner only)
     */
    function toggleBoardStatus() external onlyOwner {
        isActive = !isActive;
        emit BoardStatusChanged(isActive, msg.sender);
    }

    /**
     * @dev Update board name (owner only)
     * @param newName New board name
     */
    function updateBoardName(string memory newName) external onlyOwner {
        require(bytes(newName).length > 0, "Board name cannot be empty");
        boardName = newName;
    }

    /**
     * @dev Transfer ownership (owner only)
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
