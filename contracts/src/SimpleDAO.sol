// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleDAO
 * @dev A basic DAO for managing proposals and a treasury.
 * @notice Members can vote on proposals to execute on-chain actions.
 */
contract SimpleDAO is Ownable, ReentrancyGuard {

    // Struct for a member
    struct Member {
        bool isMember;
        uint256 joinedAt;
    }

    // Enum for proposal status
    enum ProposalStatus { PENDING, ACTIVE, SUCCEEDED, DEFEATED, EXECUTED, CANCELED }

    // Struct for a proposal
    struct Proposal {
        string description;
        address target;
        bytes callData;
        uint256 value;
        uint256 deadline;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalStatus status;
        mapping(address => bool) hasVoted;
        bool exists;
    }

    // State variables
    uint256 public proposalCount;
    uint256 public memberCount;
    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    uint256 public votingPeriod = 7 days;
    uint256 public quorumBasisPoints = 2000; // 20% of members must vote

    // Events
    event MemberAdded(address indexed member);
    event MemberRemoved(address indexed member);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool inFavor);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalStatusChanged(uint256 indexed proposalId, ProposalStatus newStatus);

    /**
     * @dev Constructor.
     */
    constructor() Ownable() {
        _addMember(msg.sender);
    }

    // --- Membership Management (Owner only) ---

    function addMember(address _newMember) external onlyOwner {
        require(!members[_newMember].isMember, "Already a member");
        _addMember(_newMember);
    }

    function removeMember(address _member) external onlyOwner {
        require(members[_member].isMember, "Not a member");
        members[_member].isMember = false;
        memberCount--;
        emit MemberRemoved(_member);
    }

    function _addMember(address _newMember) internal {
        members[_newMember] = Member({ isMember: true, joinedAt: block.timestamp });
        memberCount++;
        emit MemberAdded(_newMember);
    }

    // --- Proposal Management ---

    function createProposal(string memory _description, address _target, bytes memory _callData, uint256 _value) external returns (uint256) {
        require(members[msg.sender].isMember, "Not a member");
        uint256 proposalId = proposalCount;

        proposals[proposalId] = Proposal({
            description: _description,
            target: _target,
            callData: _callData,
            value: _value,
            deadline: block.timestamp + votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            status: ProposalStatus.ACTIVE,
            exists: true
        });

        proposalCount++;
        emit ProposalCreated(proposalId, msg.sender, _description);
        return proposalId;
    }

    function vote(uint256 _proposalId, bool _inFavor) external {
        require(members[msg.sender].isMember, "Not a member");
        Proposal storage p = proposals[_proposalId];
        require(p.exists, "Proposal not found");
        require(p.status == ProposalStatus.ACTIVE, "Proposal not active");
        require(block.timestamp < p.deadline, "Voting has ended");
        require(!p.hasVoted[msg.sender], "Already voted");

        p.hasVoted[msg.sender] = true;
        if (_inFavor) {
            p.forVotes++;
        } else {
            p.againstVotes++;
        }

        emit Voted(_proposalId, msg.sender, _inFavor);
    }

    function executeProposal(uint256 _proposalId) external nonReentrant {
        Proposal storage p = proposals[_proposalId];
        require(p.exists, "Proposal not found");
        require(p.status == ProposalStatus.ACTIVE, "Proposal not in executable state");
        require(block.timestamp >= p.deadline, "Voting still in progress");

        uint256 totalVotes = p.forVotes + p.againstVotes;
        uint256 quorum = (memberCount * quorumBasisPoints) / 10000;

        if (totalVotes < quorum) {
            p.status = ProposalStatus.DEFEATED;
            emit ProposalStatusChanged(_proposalId, ProposalStatus.DEFEATED);
            return;
        }

        if (p.forVotes > p.againstVotes) {
            p.status = ProposalStatus.SUCCEEDED;
            (bool success, ) = p.target.call{value: p.value}(p.callData);
            require(success, "Execution failed");
            p.status = ProposalStatus.EXECUTED;
            emit ProposalExecuted(_proposalId);
        } else {
            p.status = ProposalStatus.DEFEATED;
            emit ProposalStatusChanged(_proposalId, ProposalStatus.DEFEATED);
        }
    }

    // --- Treasury ---

    receive() external payable {}

    // --- View Functions ---

    function getProposal(uint256 _proposalId) 
        external 
        view 
        returns (
            string memory, address, uint256, uint256, ProposalStatus, uint256, uint256
        )
    {
        require(proposals[_proposalId].exists, "Proposal not found");
        Proposal storage p = proposals[_proposalId];
        return (p.description, p.target, p.deadline, p.value, p.status, p.forVotes, p.againstVotes);
    }

    function isMember(address _user) external view returns (bool) {
        return members[_user].isMember;
    }
}
