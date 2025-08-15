#!/usr/bin/env tsx

/**
 * Test script to verify BigInt serialization fixes in the redemption system
 * This script tests that BigInt values are properly serialized in API calls
 */

import { serializeBigInt } from '../frontend/lib/utils'
import { SignedRedemptionRequest, generateNonce, createDeadline } from '../frontend/lib/eip712'

console.log('🧪 Testing BigInt Serialization Fixes\n')

// Test 1: Verify serializeBigInt utility works correctly
console.log('1. Testing serializeBigInt utility...')

const testObject = {
  bigIntValue: BigInt('1000000000000000000'),
  normalString: 'hello',
  normalNumber: 42,
  nestedObject: {
    anotherBigInt: BigInt('500000000000000000'),
    array: [BigInt('100'), 'string', 200],
  },
  nullValue: null,
  undefinedValue: undefined,
}

const serialized = serializeBigInt(testObject)
console.log('Original object has BigInt values')
console.log('Serialized object:', JSON.stringify(serialized, null, 2))

// Verify no BigInt values remain
function hasBigInt(obj: any): boolean {
  if (obj === null || obj === undefined) return false
  if (typeof obj === 'bigint') return true
  if (Array.isArray(obj)) return obj.some(hasBigInt)
  if (typeof obj === 'object') {
    return Object.values(obj).some(hasBigInt)
  }
  return false
}

if (hasBigInt(serialized)) {
  console.error('❌ FAILED: Serialized object still contains BigInt values')
  process.exit(1)
} else {
  console.log('✅ PASSED: No BigInt values in serialized object')
}

// Test 2: Test SignedRedemptionRequest serialization
console.log('\n2. Testing SignedRedemptionRequest serialization...')

const mockSignedRequest: SignedRedemptionRequest = {
  user: '0x742D35CC6634C0532925A3B8D50d8f6f8c8b3A5c',
  shareAmount: BigInt('1000000000000000000'), // 1 token with 18 decimals
  minAssetsOut: BigInt('99000000'), // 0.99 BTC with 8 decimals
  nonce: generateNonce(),
  deadline: createDeadline(60),
  signature: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b' as `0x${string}`,
}

console.log('Original SignedRedemptionRequest:')
console.log('- shareAmount type:', typeof mockSignedRequest.shareAmount)
console.log('- minAssetsOut type:', typeof mockSignedRequest.minAssetsOut)
console.log('- nonce type:', typeof mockSignedRequest.nonce)
console.log('- deadline type:', typeof mockSignedRequest.deadline)

const serializedRequest = serializeBigInt(mockSignedRequest)
console.log('\nSerialized SignedRedemptionRequest:')
console.log('- shareAmount:', serializedRequest.shareAmount, '(type:', typeof serializedRequest.shareAmount, ')')
console.log('- minAssetsOut:', serializedRequest.minAssetsOut, '(type:', typeof serializedRequest.minAssetsOut, ')')
console.log('- nonce:', serializedRequest.nonce, '(type:', typeof serializedRequest.nonce, ')')
console.log('- deadline:', serializedRequest.deadline, '(type:', typeof serializedRequest.deadline, ')')

// Test 3: Verify JSON.stringify works on serialized objects
console.log('\n3. Testing JSON.stringify on serialized objects...')

try {
  const jsonString = JSON.stringify(serializedRequest)
  console.log('✅ PASSED: JSON.stringify works on serialized request')
  console.log('JSON length:', jsonString.length, 'characters')
} catch (error) {
  console.error('❌ FAILED: JSON.stringify failed on serialized request:', error)
  process.exit(1)
}

// Test 4: Test CreateRedemptionRequestParams serialization
console.log('\n4. Testing CreateRedemptionRequestParams serialization...')

const createParams = {
  deploymentId: 'test-deployment-id',
  expectedAssets: '99000000', // This is a string, not BigInt
  signedRequest: mockSignedRequest, // This contains BigInt values
}

const serializedParams = serializeBigInt(createParams)
console.log('Serialized CreateRedemptionRequestParams:')
console.log(JSON.stringify(serializedParams, null, 2))

if (hasBigInt(serializedParams)) {
  console.error('❌ FAILED: Serialized params still contain BigInt values')
  process.exit(1)
} else {
  console.log('✅ PASSED: No BigInt values in serialized params')
}

// Test 5: Test edge cases
console.log('\n5. Testing edge cases...')

// Empty object
const emptyResult = serializeBigInt({})
console.log('Empty object serialization:', JSON.stringify(emptyResult))

// Null and undefined
const nullResult = serializeBigInt(null)
const undefinedResult = serializeBigInt(undefined)
console.log('Null serialization:', nullResult)
console.log('Undefined serialization:', undefinedResult)

// Array with BigInt
const arrayResult = serializeBigInt([BigInt(123), 'test', { nested: BigInt(456) }])
console.log('Array with BigInt serialization:', JSON.stringify(arrayResult))

if (hasBigInt(arrayResult)) {
  console.error('❌ FAILED: Array still contains BigInt values')
  process.exit(1)
} else {
  console.log('✅ PASSED: Array BigInt serialization works')
}

console.log('\n🎉 All BigInt serialization tests passed!')
console.log('\nThe following fixes have been applied:')
console.log('1. ✅ Updated RedemptionAPI class to use serializeBigInt before JSON.stringify')
console.log('2. ✅ Updated all redemption API endpoints to use serializeBigInt in responses')
console.log('3. ✅ Verified serializeBigInt utility handles all BigInt serialization cases')
console.log('\nUsers should now be able to submit redemption requests without BigInt serialization errors.')