// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PublicNotary
 * @dev A contract to create a proof of existence for any data by storing its hash.
 * @notice Users can notarize a hash to create a permanent, timestamped record.
 */
contract PublicNotary {

    // Struct to hold the proof of existence details
    struct Proof {
        address owner;
        uint256 timestamp;
        bool exists;
    }

    // Mapping from a hash to its proof
    mapping(bytes32 => Proof) public proofs;

    // Event to log when a hash is notarized
    event Notarized(bytes32 indexed dataHash, address indexed owner, uint256 timestamp);

    /**
     * @notice Notarizes a data hash, creating a permanent proof of existence.
     * @dev The hash must not have been previously notarized.
     * @param _dataHash The keccak256 hash of the data you want to notarize.
     */
    function notarize(bytes32 _dataHash) external {
        require(!proofs[_dataHash].exists, "This hash has already been notarized");

        proofs[_dataHash] = Proof({
            owner: msg.sender,
            timestamp: block.timestamp,
            exists: true
        });

        emit Notarized(_dataHash, msg.sender, block.timestamp);
    }

    /**
     * @notice Retrieves the proof of existence for a given hash.
     * @param _dataHash The hash to look up.
     * @return The owner's address and the timestamp of notarization.
     */
    function getProof(bytes32 _dataHash) external view returns (address owner, uint256 timestamp) {
        require(proofs[_dataHash].exists, "This hash has not been notarized");
        Proof storage p = proofs[_dataHash];
        return (p.owner, p.timestamp);
    }
}
