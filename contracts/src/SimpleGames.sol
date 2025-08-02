// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title SimpleGames
 * @dev A contract for simple wager-based games with a commitment scheme for fairness.
 * @notice Includes Coin Flip, Rock-Paper-Scissors, and Number Guessing.
 */
contract SimpleGames is ReentrancyGuard, Ownable {

    // Enums for game types and outcomes
    enum GameType { CoinFlip, RockPaperScissors, NumberGuessing }
    enum RPSMove { NONE, ROCK, PAPER, SCISSORS }

    // Struct for a game session
    struct Game {
        GameType gameType;
        address payable player1;
        address payable player2;
        uint256 wager;
        bytes32 commitment; // Player 1's move commitment
        RPSMove player2Move;
        uint256 guessNumber; // For number guessing
        uint256 deadline;
        bool isFinished;
        address winner;
    }

    // State variables
    uint256 public gameCount;
    mapping(uint256 => Game) public games;
    uint256 public platformFeeBasisPoints = 100; // 1%
    uint256 public constant MAX_WAGER = 1 ether;

    // Events
    event GameCreated(uint256 indexed gameId, GameType gameType, address indexed player1, uint256 wager);
    event GameJoined(uint256 indexed gameId, address indexed player2);
    event GameRevealed(uint256 indexed gameId, address winner, uint256 payout);
    event GameCanceled(uint256 indexed gameId);

    /**
     * @dev Constructor.
     */
    constructor() Ownable() {}

    /**
     * @notice Creates a new Coin Flip game.
     * @param _commitment A hash of the choice (1 for heads, 2 for tails) and a secret nonce.
     */
    function createCoinFlip(bytes32 _commitment) external payable {
        require(msg.value > 0 && msg.value <= MAX_WAGER, "Invalid wager amount");
        uint256 gameId = _createGame(GameType.CoinFlip, _commitment);
        emit GameCreated(gameId, GameType.CoinFlip, msg.sender, msg.value);
    }

    /**
     * @notice Creates a new Rock-Paper-Scissors game.
     * @param _commitment A hash of the move (1=Rock, 2=Paper, 3=Scissors) and a secret nonce.
     */
    function createRockPaperScissors(bytes32 _commitment) external payable {
        require(msg.value > 0 && msg.value <= MAX_WAGER, "Invalid wager amount");
        uint256 gameId = _createGame(GameType.RockPaperScissors, _commitment);
        emit GameCreated(gameId, GameType.RockPaperScissors, msg.sender, msg.value);
    }

    /**
     * @notice Joins an existing game.
     * @param _gameId The ID of the game to join.
     * @param _player2Move The move for player 2 (for RPS).
     */
    function joinGame(uint256 _gameId, RPSMove _player2Move) external payable {
        require(_gameId < gameCount, "Game not found");
        Game storage g = games[_gameId];

        require(g.player2 == address(0), "Game already full");
        require(msg.sender != g.player1, "Cannot play against yourself");
        require(msg.value == g.wager, "Wager must match");

        g.player2 = payable(msg.sender);
        if (g.gameType == GameType.RockPaperScissors) {
            require(_player2Move != RPSMove.NONE, "Invalid move");
            g.player2Move = _player2Move;
        }

        emit GameJoined(_gameId, msg.sender);
    }

    /**
     * @notice Reveals the first player's move to determine the winner.
     * @param _gameId The ID of the game.
     * @param _choice The original choice (1 or 2 for coin flip, 1-3 for RPS).
     * @param _nonce The secret nonce used in the commitment.
     */
    function reveal(uint256 _gameId, uint8 _choice, bytes32 _nonce) external nonReentrant {
        require(_gameId < gameCount, "Game not found");
        Game storage g = games[_gameId];

        require(msg.sender == g.player1, "Only player 1 can reveal");
        require(!g.isFinished, "Game already finished");
        require(g.player2 != address(0), "Player 2 has not joined");
        require(keccak256(abi.encodePacked(_choice, _nonce)) == g.commitment, "Invalid reveal");

        if (g.gameType == GameType.CoinFlip) {
            _resolveCoinFlip(_gameId, _choice);
        } else if (g.gameType == GameType.RockPaperScissors) {
            _resolveRPS(_gameId, RPSMove(_choice));
        }
    }

    /**
     * @notice Cancels a game if player 2 doesn't join in time.
     * @param _gameId The ID of the game.
     */
    function cancelGame(uint256 _gameId) external nonReentrant {
        require(_gameId < gameCount, "Game not found");
        Game storage g = games[_gameId];

        require(msg.sender == g.player1, "Not the creator");
        require(!g.isFinished, "Game already finished");
        require(g.player2 == address(0), "Game has been joined");
        require(block.timestamp > g.deadline, "Deadline not passed");

        g.isFinished = true;
        g.player1.transfer(g.wager);
        emit GameCanceled(_gameId);
    }

    // --- Internal Helper Functions ---

    function _createGame(GameType _gameType, bytes32 _commitment) internal returns (uint256) {
        uint256 gameId = gameCount;
        games[gameId] = Game({
            gameType: _gameType,
            player1: payable(msg.sender),
            player2: payable(address(0)),
            wager: msg.value,
            commitment: _commitment,
            player2Move: RPSMove.NONE,
            guessNumber: 0,
            deadline: block.timestamp + 1 hours,
            isFinished: false,
            winner: address(0)
        });
        gameCount++;
        return gameId;
    }

    function _resolveCoinFlip(uint256 _gameId, uint8 _player1Choice) internal {
        Game storage g = games[_gameId];
        // Player 2's choice is implicitly the opposite of player 1's
        uint8 player2Choice = (_player1Choice == 1) ? 2 : 1;
        
        // A simple way to determine winner: lowest choice wins.
        // This is arbitrary but deterministic.
        if (_player1Choice < player2Choice) {
            g.winner = g.player1;
        } else {
            g.winner = g.player2;
        }
        _finishGame(_gameId);
    }

    function _resolveRPS(uint256 _gameId, RPSMove _player1Move) internal {
        Game storage g = games[_gameId];
        RPSMove _player2Move = g.player2Move;

        if (_player1Move == _player2Move) {
            // Draw, refund both players
            g.isFinished = true;
            g.player1.transfer(g.wager);
            g.player2.transfer(g.wager);
            emit GameRevealed(_gameId, address(0), 0);
        } else if (
            (_player1Move == RPSMove.ROCK && _player2Move == RPSMove.SCISSORS) ||
            (_player1Move == RPSMove.PAPER && _player2Move == RPSMove.ROCK) ||
            (_player1Move == RPSMove.SCISSORS && _player2Move == RPSMove.PAPER)
        ) {
            g.winner = g.player1;
            _finishGame(_gameId);
        } else {
            g.winner = g.player2;
            _finishGame(_gameId);
        }
    }

    function _finishGame(uint256 _gameId) internal {
        Game storage g = games[_gameId];
        g.isFinished = true;

        uint256 totalWager = g.wager * 2;
        uint256 fee = (totalWager * platformFeeBasisPoints) / 10000;
        uint256 payout = totalWager - fee;

        payable(g.winner).transfer(payout);
        if (fee > 0) {
            payable(owner()).transfer(fee);
        }

        emit GameRevealed(_gameId, g.winner, payout);
    }

    // --- View Functions ---

    function getGame(uint256 _gameId) 
        external 
        view 
        returns (
            GameType, address, address, uint256, uint256, bool, address
        )
    {
        require(_gameId < gameCount, "Game not found");
        Game storage g = games[_gameId];
        return (g.gameType, g.player1, g.player2, g.wager, g.deadline, g.isFinished, g.winner);
    }
}
