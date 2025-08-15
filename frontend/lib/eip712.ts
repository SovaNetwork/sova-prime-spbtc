import { TypedDataDomain } from 'viem'

// EIP-712 Domain for SovaBTC Vault Redemptions
export const REDEMPTION_DOMAIN: TypedDataDomain = {
  name: 'SovaBTC Vault',
  version: '1',
  chainId: 84532, // Base Sepolia - will be dynamic based on network
  verifyingContract: '0x0000000000000000000000000000000000000000', // Will be set to vault address
}

// EIP-712 Types for Redemption Request
export const REDEMPTION_TYPES = {
  RedemptionRequest: [
    { name: 'user', type: 'address' },
    { name: 'shareAmount', type: 'uint256' },
    { name: 'minAssetsOut', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
}

// Type definitions for TypeScript
export interface RedemptionRequestData {
  user: `0x${string}`
  shareAmount: bigint
  minAssetsOut: bigint
  nonce: bigint
  deadline: bigint
}

export interface SignedRedemptionRequest extends RedemptionRequestData {
  signature: `0x${string}`
}

// Helper function to create domain with specific chainId and verifying contract
export function createRedemptionDomain(chainId: number, vaultAddress: `0x${string}`): TypedDataDomain {
  return {
    ...REDEMPTION_DOMAIN,
    chainId,
    verifyingContract: vaultAddress,
  }
}

// Helper function to generate a unique nonce
export function generateNonce(): bigint {
  return BigInt(Date.now() + Math.floor(Math.random() * 1000))
}

// Helper function to create deadline timestamp (default 1 hour from now)
export function createDeadline(minutesFromNow: number = 60): bigint {
  return BigInt(Math.floor(Date.now() / 1000) + (minutesFromNow * 60))
}

// Validation helpers
export function isSignatureExpired(deadline: bigint): boolean {
  return BigInt(Math.floor(Date.now() / 1000)) > deadline
}

export function isValidAddress(address: string): address is `0x${string}` {
  return /^0x[a-fA-F0-9]{40}$/.test(address)
}

export function validateRedemptionRequest(request: RedemptionRequestData): string[] {
  const errors: string[] = []

  if (!isValidAddress(request.user)) {
    errors.push('Invalid user address')
  }

  if (request.shareAmount <= 0n) {
    errors.push('Share amount must be greater than 0')
  }

  if (request.minAssetsOut <= 0n) {
    errors.push('Minimum assets out must be greater than 0')
  }

  if (request.nonce <= 0n) {
    errors.push('Nonce must be greater than 0')
  }

  if (isSignatureExpired(request.deadline)) {
    errors.push('Signature has expired')
  }

  return errors
}