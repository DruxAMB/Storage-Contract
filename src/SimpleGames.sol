// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title SimpleGames
 * @dev Collection of simple on-chain games with wager functionality
 * @notice Allows users to play games like coin flip, rock-paper-scissors, and number guessing with optional wagers
 */
contract SimpleGames is ReentrancyGuard, Ownable {
    // Game types
    enum GameType { COIN_FLIP, ROCK_PAPER_SCISSORS, NUMBER_GUESS }
    
    // Rock-Paper-Scissors choices
    enum RPSChoice { NONE, ROCK, PAPER, SCISSORS }
    
    // Wager status
    enum WagerStatus { OPEN, ACCEPTED, COMPLETED, CANCELLED }
    
    // Game result
    enum GameResult { PENDING, PLAYER_WIN, OPPONENT_WIN, DRAW }
    
    // Struct for coin flip game
    struct CoinFlipGame {
        address player;
        bool playerGuess;     // true = heads, false = tails
        uint256 wagerAmount;
        uint256 timestamp;
        bool isHeads;         // Actual result
        bool completed;
    }
    
    // Struct for rock-paper-scissors game
    struct RPSGame {
        address player;
        address opponent;
        RPSChoice playerChoice;
        RPSChoice opponentChoice;
        uint256 wagerAmount;
        uint256 timestamp;
        uint256 revealDeadline;
        bytes32 playerCommitment;
        GameResult result;
        bool completed;
    }
    
    // Struct for number guessing game
    struct NumberGuessGame {
        address player;
        uint8 secretNumber;   // Number to guess (1-100)
        uint8 lastGuess;      // Last guess made
        uint8 attemptsLeft;   // Number of attempts remaining
        uint8 totalAttempts;  // Total attempts allowed
        uint256 wagerAmount;
        uint256 timestamp;
        bool completed;
    }
    
    // Struct for wager
    struct Wager {
        address creator;
        address opponent;
        GameType gameType;
        uint256 amount;
        uint256 gameId;
        WagerStatus status;
    }
    
    // Game counters
    uint256 public coinFlipGamesCount;
    uint256 public rpsGamesCount;
    uint256 public numberGuessGamesCount;
    uint256 public wagersCount;
    
    // Mappings to store games
    mapping(uint256 => CoinFlipGame) public coinFlipGames;
    mapping(uint256 => RPSGame) public rpsGames;
    mapping(uint256 => NumberGuessGame) public numberGuessGames;
    mapping(uint256 => Wager) public wagers;
    
    // Platform fee (0.5% = 50 basis points)
    uint256 public platformFee = 50;
    
    // Minimum and maximum wager amounts
    uint256 public minWager = 0.001 ether;
    uint256 public maxWager = 1 ether;
    
    // Events
    event CoinFlipGameCreated(uint256 indexed gameId, address indexed player, uint256 wagerAmount);
    event CoinFlipGameCompleted(uint256 indexed gameId, address indexed player, bool playerGuess, bool result, uint256 payout);
    
    event RPSGameCreated(uint256 indexed gameId, address indexed player, uint256 wagerAmount);
    event RPSGameJoined(uint256 indexed gameId, address indexed opponent);
    event RPSGameRevealed(uint256 indexed gameId, RPSChoice playerChoice, RPSChoice opponentChoice, GameResult result);
    
    event NumberGuessGameCreated(uint256 indexed gameId, address indexed player, uint256 wagerAmount, uint8 attempts);
    event NumberGuessAttempt(uint256 indexed gameId, uint8 guess, string hint);
    event NumberGuessGameCompleted(uint256 indexed gameId, bool won, uint8 secretNumber, uint256 payout);
    
    event WagerCreated(uint256 indexed wagerId, address indexed creator, GameType gameType, uint256 amount);
    event WagerAccepted(uint256 indexed wagerId, address indexed opponent);
    event WagerCancelled(uint256 indexed wagerId);
    event WagerCompleted(uint256 indexed wagerId, address winner, uint256 amount);
    
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    
    /**
     * @dev Constructor
     */
    constructor() Ownable() {}
    
    /**
     * @dev Create a coin flip game
     * @param guess Player's guess (true = heads, false = tails)
     * @return gameId ID of the created game
     */
    function createCoinFlipGame(bool guess) external payable nonReentrant returns (uint256 gameId) {
        require(msg.value >= minWager, "Wager too small");
        require(msg.value <= maxWager, "Wager too large");
        
        gameId = coinFlipGamesCount++;
        
        coinFlipGames[gameId] = CoinFlipGame({
            player: msg.sender,
            playerGuess: guess,
            wagerAmount: msg.value,
            timestamp: block.timestamp,
            isHeads: false,
            completed: false
        });
        
        emit CoinFlipGameCreated(gameId, msg.sender, msg.value);
        
        // Execute the flip immediately
        _executeCoinFlip(gameId);
        
        return gameId;
    }
    
    /**
     * @dev Internal function to execute a coin flip
     * @param gameId ID of the game to execute
     */
    function _executeCoinFlip(uint256 gameId) internal {
        CoinFlipGame storage game = coinFlipGames[gameId];
        require(!game.completed, "Game already completed");
        
        // Generate random result using block data
        // Note: In production, use a verifiable random function or oracle
        bytes32 blockHash = blockhash(block.number - 1);
        bytes32 hash = keccak256(abi.encodePacked(blockHash, game.player, block.timestamp, gameId));
        bool isHeads = uint256(hash) % 2 == 0;
        
        game.isHeads = isHeads;
        game.completed = true;
        
        // Determine if player won
        bool playerWon = (game.playerGuess == isHeads);
        
        // Calculate payout
        uint256 payout = 0;
        if (playerWon) {
            uint256 fee = (game.wagerAmount * platformFee) / 10000;
            payout = game.wagerAmount * 2 - fee;
            payable(game.player).transfer(payout);
        } else {
            // House wins, funds stay in contract
        }
        
        emit CoinFlipGameCompleted(gameId, game.player, game.playerGuess, isHeads, payout);
    }
    
    /**
     * @dev Create a rock-paper-scissors game with commitment
     * @param commitment Hashed commitment of player's choice
     * @return gameId ID of the created game
     */
    function createRPSGame(bytes32 commitment) external payable nonReentrant returns (uint256 gameId) {
        require(msg.value >= minWager, "Wager too small");
        require(msg.value <= maxWager, "Wager too large");
        
        gameId = rpsGamesCount++;
        
        rpsGames[gameId] = RPSGame({
            player: msg.sender,
            opponent: address(0),
            playerChoice: RPSChoice.NONE,
            opponentChoice: RPSChoice.NONE,
            wagerAmount: msg.value,
            timestamp: block.timestamp,
            revealDeadline: block.timestamp + 1 days,
            playerCommitment: commitment,
            result: GameResult.PENDING,
            completed: false
        });
        
        emit RPSGameCreated(gameId, msg.sender, msg.value);
        
        return gameId;
    }
    
    /**
     * @dev Join an existing rock-paper-scissors game
     * @param gameId ID of the game to join
     * @param choice Opponent's choice (1=Rock, 2=Paper, 3=Scissors)
     */
    function joinRPSGame(uint256 gameId, RPSChoice choice) external payable nonReentrant {
        RPSGame storage game = rpsGames[gameId];
        
        require(!game.completed, "Game already completed");
        require(game.opponent == address(0), "Game already has an opponent");
        require(msg.sender != game.player, "Cannot play against yourself");
        require(choice > RPSChoice.NONE && choice <= RPSChoice.SCISSORS, "Invalid choice");
        require(msg.value == game.wagerAmount, "Must match wager amount");
        
        game.opponent = msg.sender;
        game.opponentChoice = choice;
        
        emit RPSGameJoined(gameId, msg.sender);
    }
    
    /**
     * @dev Reveal player's choice and determine winner
     * @param gameId ID of the game
     * @param choice Player's choice (1=Rock, 2=Paper, 3=Scissors)
     * @param salt Salt used in the commitment
     */
    function revealRPSGame(uint256 gameId, RPSChoice choice, bytes32 salt) external nonReentrant {
        RPSGame storage game = rpsGames[gameId];
        
        require(!game.completed, "Game already completed");
        require(msg.sender == game.player, "Only player can reveal");
        require(game.opponent != address(0), "No opponent yet");
        require(choice > RPSChoice.NONE && choice <= RPSChoice.SCISSORS, "Invalid choice");
        require(block.timestamp <= game.revealDeadline, "Reveal deadline passed");
        
        // Verify commitment
        bytes32 commitment = keccak256(abi.encodePacked(choice, salt, msg.sender));
        require(commitment == game.playerCommitment, "Invalid commitment");
        
        game.playerChoice = choice;
        
        // Determine winner
        if (game.playerChoice == game.opponentChoice) {
            game.result = GameResult.DRAW;
        } else if (
            (game.playerChoice == RPSChoice.ROCK && game.opponentChoice == RPSChoice.SCISSORS) ||
            (game.playerChoice == RPSChoice.PAPER && game.opponentChoice == RPSChoice.ROCK) ||
            (game.playerChoice == RPSChoice.SCISSORS && game.opponentChoice == RPSChoice.PAPER)
        ) {
            game.result = GameResult.PLAYER_WIN;
        } else {
            game.result = GameResult.OPPONENT_WIN;
        }
        
        game.completed = true;
        
        // Distribute winnings
        uint256 totalWager = game.wagerAmount * 2;
        uint256 fee = (totalWager * platformFee) / 10000;
        uint256 winnings = totalWager - fee;
        
        if (game.result == GameResult.DRAW) {
            // Return wagers minus half fee each
            uint256 halfFee = fee / 2;
            payable(game.player).transfer(game.wagerAmount - halfFee);
            payable(game.opponent).transfer(game.wagerAmount - halfFee);
        } else if (game.result == GameResult.PLAYER_WIN) {
            payable(game.player).transfer(winnings);
        } else {
            payable(game.opponent).transfer(winnings);
        }
        
        emit RPSGameRevealed(gameId, game.playerChoice, game.opponentChoice, game.result);
    }
    
    /**
     * @dev Create a number guessing game
     * @param secretNumber Secret number to guess (1-100)
     * @param attempts Number of attempts allowed
     * @return gameId ID of the created game
     */
    function createNumberGuessGame(uint8 secretNumber, uint8 attempts) external payable nonReentrant returns (uint256 gameId) {
        require(msg.value >= minWager, "Wager too small");
        require(msg.value <= maxWager, "Wager too large");
        require(secretNumber >= 1 && secretNumber <= 100, "Number must be 1-100");
        require(attempts >= 3 && attempts <= 10, "Attempts must be 3-10");
        
        gameId = numberGuessGamesCount++;
        
        numberGuessGames[gameId] = NumberGuessGame({
            player: msg.sender,
            secretNumber: secretNumber,
            lastGuess: 0,
            attemptsLeft: attempts,
            totalAttempts: attempts,
            wagerAmount: msg.value,
            timestamp: block.timestamp,
            completed: false
        });
        
        emit NumberGuessGameCreated(gameId, msg.sender, msg.value, attempts);
        
        return gameId;
    }
    
    /**
     * @dev Make a guess in a number guessing game
     * @param gameId ID of the game
     * @param guess The guessed number (1-100)
     */
    function makeGuess(uint256 gameId, uint8 guess) external payable nonReentrant {
        require(guess >= 1 && guess <= 100, "Guess must be 1-100");
        
        NumberGuessGame storage game = numberGuessGames[gameId];
        
        require(!game.completed, "Game already completed");
        require(msg.sender != game.player, "Creator cannot guess");
        
        // First guess requires matching the wager
        if (game.attemptsLeft == game.totalAttempts) {
            require(msg.value == game.wagerAmount, "Must match wager amount");
        } else {
            require(msg.value == 0, "No payment for subsequent guesses");
        }
        
        game.lastGuess = guess;
        game.attemptsLeft--;
        
        string memory hint;
        
        // Check if guess is correct
        if (guess == game.secretNumber) {
            // Player wins
            game.completed = true;
            
            // Calculate winnings
            uint256 totalWager = game.wagerAmount * 2;
            uint256 fee = (totalWager * platformFee) / 10000;
            uint256 winnings = totalWager - fee;
            
            payable(msg.sender).transfer(winnings);
            
            hint = "Correct!";
            emit NumberGuessGameCompleted(gameId, true, game.secretNumber, winnings);
        } else {
            // Provide hint
            if (guess < game.secretNumber) {
                hint = "Higher";
            } else {
                hint = "Lower";
            }
            
            // Check if attempts are exhausted
            if (game.attemptsLeft == 0) {
                game.completed = true;
                
                // Game creator wins
                uint256 totalWager = game.wagerAmount * 2;
                uint256 fee = (totalWager * platformFee) / 10000;
                uint256 winnings = totalWager - fee;
                
                payable(game.player).transfer(winnings);
                
                emit NumberGuessGameCompleted(gameId, false, game.secretNumber, winnings);
            }
        }
        
        emit NumberGuessAttempt(gameId, guess, hint);
    }
    
    /**
     * @dev Create a wager for any game type
     * @param gameType Type of game (0=CoinFlip, 1=RPS, 2=NumberGuess)
     * @return wagerId ID of the created wager
     */
    function createWager(GameType gameType) external payable nonReentrant returns (uint256 wagerId) {
        require(msg.value >= minWager, "Wager too small");
        require(msg.value <= maxWager, "Wager too large");
        
        wagerId = wagersCount++;
        
        wagers[wagerId] = Wager({
            creator: msg.sender,
            opponent: address(0),
            gameType: gameType,
            amount: msg.value,
            gameId: 0,
            status: WagerStatus.OPEN
        });
        
        emit WagerCreated(wagerId, msg.sender, gameType, msg.value);
        
        return wagerId;
    }
    
    /**
     * @dev Accept a wager and start the corresponding game
     * @param wagerId ID of the wager to accept
     */
    function acceptWager(uint256 wagerId) external payable nonReentrant {
        Wager storage wager = wagers[wagerId];
        
        require(wager.status == WagerStatus.OPEN, "Wager not open");
        require(msg.sender != wager.creator, "Cannot accept own wager");
        require(msg.value == wager.amount, "Must match wager amount");
        
        wager.opponent = msg.sender;
        wager.status = WagerStatus.ACCEPTED;
        
        emit WagerAccepted(wagerId, msg.sender);
        
        // Create the actual game based on type
        if (wager.gameType == GameType.COIN_FLIP) {
            // For coin flip, we'll use a special internal function
            uint256 gameId = _createWageredCoinFlip(wager.creator, wager.opponent, wager.amount);
            wager.gameId = gameId;
        }
        // Other game types would be handled similarly
    }
    
    /**
     * @dev Internal function to create a wagered coin flip game
     * @return gameId ID of the created game
     */
    function _createWageredCoinFlip(
        address /* player1 */, 
        address /* player2 */, 
        uint256 /* amount */
    ) internal pure returns (uint256 gameId) {
        // Implementation would create a special coin flip game between the two players
        // This is a simplified placeholder
        return 0;
    }
    
    /**
     * @dev Cancel a wager (only creator can cancel)
     * @param wagerId ID of the wager to cancel
     */
    function cancelWager(uint256 wagerId) external nonReentrant {
        Wager storage wager = wagers[wagerId];
        
        require(wager.status == WagerStatus.OPEN, "Wager not open");
        require(msg.sender == wager.creator, "Only creator can cancel");
        
        wager.status = WagerStatus.CANCELLED;
        
        // Return funds to creator
        payable(wager.creator).transfer(wager.amount);
        
        emit WagerCancelled(wagerId);
    }
    
    /**
     * @dev Update platform fee (owner only)
     * @param newFee New platform fee in basis points
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 500, "Fee too high"); // Max 5%
        
        uint256 oldFee = platformFee;
        platformFee = newFee;
        
        emit PlatformFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev Update wager limits (owner only)
     * @param newMinWager New minimum wager amount
     * @param newMaxWager New maximum wager amount
     */
    function updateWagerLimits(uint256 newMinWager, uint256 newMaxWager) external onlyOwner {
        require(newMinWager < newMaxWager, "Min must be less than max");
        
        minWager = newMinWager;
        maxWager = newMaxWager;
    }
    
    /**
     * @dev Withdraw platform fees (owner only)
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev Helper function to generate a commitment for RPS
     * @param choice Player's choice (1=Rock, 2=Paper, 3=Scissors)
     * @param salt Random salt for commitment
     * @return commitment Hashed commitment
     */
    function generateCommitment(RPSChoice choice, bytes32 salt) external view returns (bytes32 commitment) {
        require(choice > RPSChoice.NONE && choice <= RPSChoice.SCISSORS, "Invalid choice");
        return keccak256(abi.encodePacked(choice, salt, msg.sender));
    }
}
