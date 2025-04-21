/**
 * Withdrawal Utilities for Fountfi
 * Provides helper functions for generating Merkle trees and proofs
 * for the withdrawal approval system.
 */

// Import libraries - these may need to be installed with npm first
// npm install ethers keccak256 merkletreejs

const { ethers } = require('ethers');
const keccak256 = require('keccak256');
const { MerkleTree } = require('merkletreejs');

/**
 * Generate a leaf node from withdrawal request data
 * @param {number} requestId - Unique identifier for the withdrawal request
 * @param {string} user - Address of the user requesting withdrawal
 * @param {string} assets - Amount of assets to withdraw (in wei/smallest units)
 * @returns {Buffer} The hashed leaf node
 */
function generateLeaf(requestId, user, assets) {
    // Pack the data in the same way the smart contract does
    const packedData = ethers.utils.solidityPack(
        ['uint256', 'address', 'uint256'],
        [requestId, user, assets]
    );
    
    // Hash the packed data
    return keccak256(packedData);
}

/**
 * Generate a Merkle tree from an array of withdrawal requests
 * @param {Array} requests - Array of withdrawal request objects
 * @returns {Object} MerkleTree object
 */
function generateMerkleTree(requests) {
    // Generate leaf nodes
    const leaves = requests.map(req => generateLeaf(
        req.id,
        req.user,
        req.assets
    ));
    
    // Create the Merkle tree
    return new MerkleTree(leaves, keccak256, { sort: true });
}

/**
 * Generate a proof for a specific withdrawal request
 * @param {Object} tree - MerkleTree object
 * @param {number} requestId - ID of the withdrawal request
 * @param {string} user - Address of the user
 * @param {string} assets - Amount of assets
 * @returns {Array} Merkle proof
 */
function generateProof(tree, requestId, user, assets) {
    const leaf = generateLeaf(requestId, user, assets);
    return tree.getHexProof(leaf);
}

/**
 * Get the Merkle root from a tree
 * @param {Object} tree - MerkleTree object
 * @returns {string} Merkle root as hex string
 */
function getMerkleRoot(tree) {
    return tree.getHexRoot();
}

/**
 * Process a batch of withdrawal requests and return the Merkle tree data
 * @param {Array} requests - Array of withdrawal request objects
 * @returns {Object} Object containing the tree, root, and proofs
 */
function processWithdrawalBatch(requests) {
    // Generate the tree
    const tree = generateMerkleTree(requests);
    
    // Get the Merkle root
    const root = getMerkleRoot(tree);
    
    // Generate proofs for each request
    const proofs = requests.map(req => ({
        id: req.id,
        user: req.user,
        assets: req.assets,
        proof: generateProof(tree, req.id, req.user, req.assets)
    }));
    
    return {
        tree,
        root,
        proofs
    };
}

/**
 * Verify a Merkle proof
 * @param {Array} proof - Merkle proof array
 * @param {string} root - Merkle root hex string
 * @param {number} requestId - ID of the withdrawal request
 * @param {string} user - Address of the user
 * @param {string} assets - Amount of assets
 * @returns {boolean} Whether the proof is valid
 */
function verifyProof(proof, root, requestId, user, assets) {
    const leaf = generateLeaf(requestId, user, assets);
    return MerkleTree.verify(proof, leaf, root, keccak256, { sort: true });
}

module.exports = {
    generateLeaf,
    generateMerkleTree,
    generateProof,
    getMerkleRoot,
    processWithdrawalBatch,
    verifyProof
};