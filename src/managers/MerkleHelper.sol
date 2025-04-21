// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title MerkleHelper
 * @notice Utility contract for Merkle tree operations
 * @dev Helper functions for creating and verifying Merkle proofs for withdrawal approvals
 */
contract MerkleHelper {
    /**
     * @notice Compute a leaf node for a withdrawal request
     * @param requestId Unique identifier for the withdrawal
     * @param user Address of the user
     * @param assets Amount of assets to withdraw
     * @return Leaf node hash
     */
    function computeLeaf(uint256 requestId, address user, uint256 assets) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(requestId, user, assets));
    }

    /**
     * @notice Compute a Merkle tree node from two child nodes
     * @param left Left child node
     * @param right Right child node
     * @return Node hash
     */
    function computeNode(bytes32 left, bytes32 right) public pure returns (bytes32) {
        return left <= right
            ? keccak256(abi.encodePacked(left, right))
            : keccak256(abi.encodePacked(right, left));
    }

    /**
     * @notice Compute the Merkle root from an array of leaf nodes
     * @param leaves Array of leaf nodes
     * @return Merkle root
     */
    function computeRoot(bytes32[] memory leaves) public pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");

        if (leaves.length == 1) {
            return leaves[0];
        }

        bytes32[] memory currentLevel = leaves;

        while (currentLevel.length > 1) {
            bytes32[] memory nextLevel = new bytes32[]((currentLevel.length + 1) / 2);

            for (uint256 i = 0; i < nextLevel.length; i++) {
                uint256 leftIndex = i * 2;
                uint256 rightIndex = leftIndex + 1;

                bytes32 left = currentLevel[leftIndex];
                bytes32 right = rightIndex < currentLevel.length ? currentLevel[rightIndex] : left;

                nextLevel[i] = computeNode(left, right);
            }

            currentLevel = nextLevel;
        }

        return currentLevel[0];
    }

    /**
     * @notice Generate a Merkle proof for a specific leaf
     * @param leaves Array of all leaf nodes
     * @param index Index of the target leaf
     * @return Merkle proof
     */
    function getProof(bytes32[] memory leaves, uint256 index) public pure returns (bytes32[] memory) {
        require(leaves.length > 0, "Empty leaves");
        require(index < leaves.length, "Index out of bounds");

        if (leaves.length == 1) {
            return new bytes32[](0);
        }

        // Calculate tree height
        uint256 height = 0;
        uint256 levelSize = leaves.length;
        while (levelSize > 1) {
            height++;
            levelSize = (levelSize + 1) / 2;
        }

        bytes32[] memory proof = new bytes32[](height);
        uint256 proofIndex = 0;

        bytes32[] memory currentLevel = leaves;
        uint256 currentIndex = index;

        for (uint256 level = 0; level < height; level++) {
            uint256 siblingIndex = currentIndex % 2 == 0 ? currentIndex + 1 : currentIndex - 1;

            if (siblingIndex < currentLevel.length) {
                proof[proofIndex++] = currentLevel[siblingIndex];
            } else {
                // If sibling is out of bounds, use currentIndex's value
                proof[proofIndex++] = currentLevel[currentIndex];
            }

            // Move to next level
            currentIndex = currentIndex / 2;
            
            // Build the next level
            bytes32[] memory nextLevel = new bytes32[]((currentLevel.length + 1) / 2);
            for (uint256 i = 0; i < nextLevel.length; i++) {
                uint256 left = i * 2;
                uint256 right = left + 1;
                if (right < currentLevel.length) {
                    nextLevel[i] = computeNode(currentLevel[left], currentLevel[right]);
                } else {
                    nextLevel[i] = currentLevel[left];
                }
            }
            currentLevel = nextLevel;
        }

        return proof;
    }

    /**
     * @notice Verify a Merkle proof
     * @param proof Merkle proof
     * @param root Merkle root
     * @param leaf Target leaf node
     * @return Whether the proof is valid
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) public pure returns (bool) {
        bytes32 current = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            current = computeNode(current, proof[i]);
        }

        return current == root;
    }
}