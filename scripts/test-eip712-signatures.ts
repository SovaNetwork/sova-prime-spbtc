#!/usr/bin/env node

import { privateKeyToAccount, generatePrivateKey } from 'viem/accounts'
import { createWalletClient, http, parseEther, verifyTypedData, recoverTypedDataAddress } from 'viem'
import { baseSepolia, mainnet } from 'viem/chains'
import {
  createRedemptionDomain,
  generateNonce,
  createDeadline,
  validateRedemptionRequest,
  isSignatureExpired,
  isValidAddress,
  REDEMPTION_TYPES,
  REDEMPTION_DOMAIN,
  type RedemptionRequestData,
  type SignedRedemptionRequest
} from '../frontend/lib/eip712'

// Test configuration
const config = {
  chainId: 84532, // Base Sepolia
  vaultAddress: '0x742d35Cc6634C0532925a3b8D23dC6e74c4b8e1D' as `0x${string}`,
  testPrivateKeys: [
    generatePrivateKey(),
    generatePrivateKey(),
    generatePrivateKey(),
  ],
}

class EIP712SignatureTestSuite {
  private testUsers: ReturnType<typeof privateKeyToAccount>[]
  private testSignatures: SignedRedemptionRequest[] = []

  constructor() {
    this.testUsers = config.testPrivateKeys.map(pk => privateKeyToAccount(pk))
    console.log('🔐 Test Users:')
    this.testUsers.forEach((user, index) => {
      console.log(`   ${index + 1}. ${user.address}`)
    })
  }

  // Utility to create wallet client for a user
  private createWalletClient(userIndex: number = 0) {
    return createWalletClient({
      account: this.testUsers[userIndex],
      chain: baseSepolia,
      transport: http()
    })
  }

  // Test 1: Domain Configuration
  async testDomainConfiguration(): Promise<boolean> {
    console.log('\n🌐 Test 1: Domain Configuration')
    try {
      // Test default domain
      console.log('✅ Default REDEMPTION_DOMAIN:')
      console.log(`   Name: ${REDEMPTION_DOMAIN.name}`)
      console.log(`   Version: ${REDEMPTION_DOMAIN.version}`)
      console.log(`   ChainId: ${REDEMPTION_DOMAIN.chainId}`)
      console.log(`   Verifying Contract: ${REDEMPTION_DOMAIN.verifyingContract}`)

      // Test dynamic domain creation
      const dynamicDomain = createRedemptionDomain(config.chainId, config.vaultAddress)
      console.log('✅ Dynamic domain created:')
      console.log(`   Name: ${dynamicDomain.name}`)
      console.log(`   Version: ${dynamicDomain.version}`)
      console.log(`   ChainId: ${dynamicDomain.chainId}`)
      console.log(`   Verifying Contract: ${dynamicDomain.verifyingContract}`)

      // Test different chain IDs
      const mainnetDomain = createRedemptionDomain(1, config.vaultAddress)
      const arbitrumDomain = createRedemptionDomain(42161, config.vaultAddress)

      console.log('✅ Cross-chain domain support:')
      console.log(`   Mainnet ChainId: ${mainnetDomain.chainId}`)
      console.log(`   Arbitrum ChainId: ${arbitrumDomain.chainId}`)

      return true
    } catch (error) {
      console.log(`❌ Domain configuration test failed: ${error}`)
      return false
    }
  }

  // Test 2: Type Definition Validation
  async testTypeDefinitions(): Promise<boolean> {
    console.log('\n📋 Test 2: Type Definition Validation')
    try {
      console.log('✅ REDEMPTION_TYPES structure:')
      console.log(JSON.stringify(REDEMPTION_TYPES, null, 2))

      // Validate type structure
      const expectedFields = ['user', 'shareAmount', 'minAssetsOut', 'nonce', 'deadline']
      const actualFields = REDEMPTION_TYPES.RedemptionRequest.map(field => field.name)

      if (expectedFields.every(field => actualFields.includes(field))) {
        console.log('✅ All expected fields present in type definition')
      } else {
        console.log('❌ Missing fields in type definition')
        console.log(`   Expected: ${expectedFields}`)
        console.log(`   Actual: ${actualFields}`)
        return false
      }

      // Validate field types
      const typeMapping = {
        user: 'address',
        shareAmount: 'uint256',
        minAssetsOut: 'uint256',
        nonce: 'uint256',
        deadline: 'uint256'
      }

      let typeValidation = true
      REDEMPTION_TYPES.RedemptionRequest.forEach(field => {
        const expectedType = typeMapping[field.name as keyof typeof typeMapping]
        if (expectedType && field.type !== expectedType) {
          console.log(`❌ Incorrect type for ${field.name}: expected ${expectedType}, got ${field.type}`)
          typeValidation = false
        }
      })

      if (typeValidation) {
        console.log('✅ All field types are correct')
      }

      return typeValidation
    } catch (error) {
      console.log(`❌ Type definition test failed: ${error}`)
      return false
    }
  }

  // Test 3: Signature Generation
  async testSignatureGeneration(): Promise<boolean> {
    console.log('\n✍️  Test 3: Signature Generation')
    try {
      const domain = createRedemptionDomain(config.chainId, config.vaultAddress)
      const walletClient = this.createWalletClient(0)

      // Create test redemption request data
      const requestData: RedemptionRequestData = {
        user: this.testUsers[0].address,
        shareAmount: parseEther('1'),
        minAssetsOut: parseEther('0.95'),
        nonce: generateNonce(),
        deadline: createDeadline(60)
      }

      console.log('✅ Redemption request data:')
      console.log(`   User: ${requestData.user}`)
      console.log(`   Share Amount: ${requestData.shareAmount}`)
      console.log(`   Min Assets Out: ${requestData.minAssetsOut}`)
      console.log(`   Nonce: ${requestData.nonce}`)
      console.log(`   Deadline: ${requestData.deadline}`)

      // Generate signature
      const signature = await walletClient.signTypedData({
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData
      })

      console.log(`✅ Signature generated: ${signature}`)
      console.log(`   Length: ${signature.length}`)
      console.log(`   Starts with 0x: ${signature.startsWith('0x')}`)

      // Store for later tests
      this.testSignatures.push({
        ...requestData,
        signature
      })

      return true
    } catch (error) {
      console.log(`❌ Signature generation failed: ${error}`)
      return false
    }
  }

  // Test 4: Signature Verification
  async testSignatureVerification(): Promise<boolean> {
    console.log('\n✅ Test 4: Signature Verification')
    try {
      if (this.testSignatures.length === 0) {
        console.log('⚠️  No test signatures available')
        return false
      }

      const domain = createRedemptionDomain(config.chainId, config.vaultAddress)
      const signedRequest = this.testSignatures[0]

      // Test valid signature verification
      const isValid = await verifyTypedData({
        address: signedRequest.user,
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: {
          user: signedRequest.user,
          shareAmount: signedRequest.shareAmount,
          minAssetsOut: signedRequest.minAssetsOut,
          nonce: signedRequest.nonce,
          deadline: signedRequest.deadline
        },
        signature: signedRequest.signature
      })

      if (isValid) {
        console.log('✅ Valid signature verification passed')
      } else {
        console.log('❌ Valid signature verification failed')
        return false
      }

      // Test invalid signature verification (wrong signer)
      const isInvalidSigner = await verifyTypedData({
        address: this.testUsers[1].address, // Different user
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: {
          user: signedRequest.user,
          shareAmount: signedRequest.shareAmount,
          minAssetsOut: signedRequest.minAssetsOut,
          nonce: signedRequest.nonce,
          deadline: signedRequest.deadline
        },
        signature: signedRequest.signature
      })

      if (!isInvalidSigner) {
        console.log('✅ Invalid signer correctly rejected')
      } else {
        console.log('❌ Invalid signer incorrectly accepted')
        return false
      }

      // Test signature recovery
      const recoveredAddress = await recoverTypedDataAddress({
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: {
          user: signedRequest.user,
          shareAmount: signedRequest.shareAmount,
          minAssetsOut: signedRequest.minAssetsOut,
          nonce: signedRequest.nonce,
          deadline: signedRequest.deadline
        },
        signature: signedRequest.signature
      })

      if (recoveredAddress.toLowerCase() === signedRequest.user.toLowerCase()) {
        console.log(`✅ Address recovery successful: ${recoveredAddress}`)
      } else {
        console.log(`❌ Address recovery failed: expected ${signedRequest.user}, got ${recoveredAddress}`)
        return false
      }

      return true
    } catch (error) {
      console.log(`❌ Signature verification failed: ${error}`)
      return false
    }
  }

  // Test 5: Cross-Chain Domain Validation
  async testCrossChainDomains(): Promise<boolean> {
    console.log('\n🌍 Test 5: Cross-Chain Domain Validation')
    try {
      const baseSepoliaDomain = createRedemptionDomain(84532, config.vaultAddress)
      const mainnetDomain = createRedemptionDomain(1, config.vaultAddress)

      // Create same request data
      const requestData: RedemptionRequestData = {
        user: this.testUsers[0].address,
        shareAmount: parseEther('1'),
        minAssetsOut: parseEther('0.95'),
        nonce: generateNonce(),
        deadline: createDeadline(60)
      }

      // Sign with Base Sepolia domain
      const baseSepoliaWallet = createWalletClient({
        account: this.testUsers[0],
        chain: baseSepolia,
        transport: http()
      })

      const baseSepoliaSignature = await baseSepoliaWallet.signTypedData({
        domain: baseSepoliaDomain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData
      })

      console.log('✅ Base Sepolia signature generated')

      // Sign with Mainnet domain
      const mainnetWallet = createWalletClient({
        account: this.testUsers[0],
        chain: mainnet,
        transport: http()
      })

      const mainnetSignature = await mainnetWallet.signTypedData({
        domain: mainnetDomain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData
      })

      console.log('✅ Mainnet signature generated')

      // Signatures should be different for different chains
      if (baseSepoliaSignature !== mainnetSignature) {
        console.log('✅ Cross-chain signatures are properly differentiated')
      } else {
        console.log('❌ Cross-chain signatures are identical (security issue)')
        return false
      }

      // Verify each signature only works with its respective domain
      const baseSepoliaValid = await verifyTypedData({
        address: requestData.user,
        domain: baseSepoliaDomain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData,
        signature: baseSepoliaSignature
      })

      const mainnetValid = await verifyTypedData({
        address: requestData.user,
        domain: mainnetDomain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData,
        signature: mainnetSignature
      })

      if (baseSepoliaValid && mainnetValid) {
        console.log('✅ Each signature validates with its respective domain')
      } else {
        console.log('❌ Domain-specific signature validation failed')
        return false
      }

      // Test cross-domain invalidation
      const crossDomainValid = await verifyTypedData({
        address: requestData.user,
        domain: mainnetDomain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData,
        signature: baseSepoliaSignature // Wrong signature for this domain
      })

      if (!crossDomainValid) {
        console.log('✅ Cross-domain signature correctly rejected')
      } else {
        console.log('❌ Cross-domain signature incorrectly accepted')
        return false
      }

      return true
    } catch (error) {
      console.log(`❌ Cross-chain domain test failed: ${error}`)
      return false
    }
  }

  // Test 6: Signature Manipulation Detection
  async testSignatureManipulation(): Promise<boolean> {
    console.log('\n🛡️  Test 6: Signature Manipulation Detection')
    try {
      if (this.testSignatures.length === 0) {
        console.log('⚠️  No test signatures available')
        return false
      }

      const domain = createRedemptionDomain(config.chainId, config.vaultAddress)
      const originalRequest = this.testSignatures[0]

      // Test 1: Modified message data
      const modifiedRequest = {
        ...originalRequest,
        shareAmount: originalRequest.shareAmount + 1n // Slightly different amount
      }

      const isModifiedValid = await verifyTypedData({
        address: originalRequest.user,
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: modifiedRequest,
        signature: originalRequest.signature
      })

      if (!isModifiedValid) {
        console.log('✅ Modified message data correctly rejected')
      } else {
        console.log('❌ Modified message data incorrectly accepted')
        return false
      }

      // Test 2: Truncated signature
      const truncatedSignature = originalRequest.signature.slice(0, -2) as `0x${string}`

      try {
        await verifyTypedData({
          address: originalRequest.user,
          domain,
          types: REDEMPTION_TYPES,
          primaryType: 'RedemptionRequest',
          message: originalRequest,
          signature: truncatedSignature
        })
        console.log('❌ Truncated signature should have been rejected')
        return false
      } catch (error) {
        console.log('✅ Truncated signature correctly rejected')
      }

      // Test 3: Modified signature
      let modifiedSignature = originalRequest.signature
      // Flip one bit in the signature
      const lastChar = modifiedSignature.slice(-1)
      const flippedChar = lastChar === 'a' ? 'b' : 'a'
      modifiedSignature = (modifiedSignature.slice(0, -1) + flippedChar) as `0x${string}`

      const isModifiedSigValid = await verifyTypedData({
        address: originalRequest.user,
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: originalRequest,
        signature: modifiedSignature
      })

      if (!isModifiedSigValid) {
        console.log('✅ Modified signature correctly rejected')
      } else {
        console.log('❌ Modified signature incorrectly accepted')
        return false
      }

      return true
    } catch (error) {
      console.log(`❌ Signature manipulation test failed: ${error}`)
      return false
    }
  }

  // Test 7: Validation Helper Functions
  async testValidationHelpers(): Promise<boolean> {
    console.log('\n🔍 Test 7: Validation Helper Functions')
    try {
      // Test address validation
      const validAddresses = [
        '0x742d35Cc6634C0532925a3b8D23dC6e74c4b8e1D',
        '0x0000000000000000000000000000000000000000',
        '0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF',
      ]

      const invalidAddresses = [
        '742d35Cc6634C0532925a3b8D23dC6e74c4b8e1D', // Missing 0x
        '0x742d35Cc6634C0532925a3b8D23dC6e74c4b8e1', // Too short
        '0x742d35Cc6634C0532925a3b8D23dC6e74c4b8e1DZ', // Invalid character
        '', // Empty
        '0x', // Only prefix
      ]

      let addressValidationPassed = true
      
      validAddresses.forEach(addr => {
        if (!isValidAddress(addr)) {
          console.log(`❌ Valid address rejected: ${addr}`)
          addressValidationPassed = false
        }
      })

      invalidAddresses.forEach(addr => {
        if (isValidAddress(addr)) {
          console.log(`❌ Invalid address accepted: ${addr}`)
          addressValidationPassed = false
        }
      })

      if (addressValidationPassed) {
        console.log('✅ Address validation working correctly')
      }

      // Test signature expiry
      const currentTime = Math.floor(Date.now() / 1000)
      const expiredDeadline = BigInt(currentTime - 3600) // 1 hour ago
      const validDeadline = BigInt(currentTime + 3600) // 1 hour from now

      if (isSignatureExpired(expiredDeadline)) {
        console.log('✅ Expired signature correctly identified')
      } else {
        console.log('❌ Expired signature not identified')
        addressValidationPassed = false
      }

      if (!isSignatureExpired(validDeadline)) {
        console.log('✅ Valid signature correctly identified as not expired')
      } else {
        console.log('❌ Valid signature incorrectly marked as expired')
        addressValidationPassed = false
      }

      // Test request validation
      const validRequest: RedemptionRequestData = {
        user: this.testUsers[0].address,
        shareAmount: parseEther('1'),
        minAssetsOut: parseEther('0.95'),
        nonce: generateNonce(),
        deadline: createDeadline(60)
      }

      const validationErrors = validateRedemptionRequest(validRequest)
      if (validationErrors.length === 0) {
        console.log('✅ Valid request passes validation')
      } else {
        console.log(`❌ Valid request failed validation: ${validationErrors.join(', ')}`)
        addressValidationPassed = false
      }

      // Test invalid request
      const invalidRequest: RedemptionRequestData = {
        user: 'invalid-address' as `0x${string}`,
        shareAmount: 0n,
        minAssetsOut: 0n,
        nonce: 0n,
        deadline: BigInt(currentTime - 3600)
      }

      const invalidErrors = validateRedemptionRequest(invalidRequest)
      if (invalidErrors.length > 0) {
        console.log(`✅ Invalid request correctly rejected with errors: ${invalidErrors.join(', ')}`)
      } else {
        console.log('❌ Invalid request incorrectly passed validation')
        addressValidationPassed = false
      }

      return addressValidationPassed
    } catch (error) {
      console.log(`❌ Validation helpers test failed: ${error}`)
      return false
    }
  }

  // Test 8: Nonce and Deadline Generation
  async testNonceAndDeadlineGeneration(): Promise<boolean> {
    console.log('\n🎲 Test 8: Nonce and Deadline Generation')
    try {
      // Test nonce generation uniqueness
      const nonces = Array.from({ length: 10 }, () => generateNonce())
      const uniqueNonces = new Set(nonces)

      if (uniqueNonces.size === nonces.length) {
        console.log(`✅ Generated ${nonces.length} unique nonces`)
      } else {
        console.log(`❌ Nonce collision detected: ${nonces.length} generated, ${uniqueNonces.size} unique`)
        return false
      }

      // Test nonce values are reasonable
      nonces.forEach(nonce => {
        if (nonce > 0n) {
          console.log(`✅ Nonce ${nonce} is positive`)
        } else {
          console.log(`❌ Nonce ${nonce} is not positive`)
          return false
        }
      })

      // Test deadline generation
      const currentTime = Math.floor(Date.now() / 1000)
      const deadline5Min = createDeadline(5)
      const deadline1Hour = createDeadline(60)
      const deadline1Day = createDeadline(1440)

      const deadline5MinSecs = Number(deadline5Min)
      const deadline1HourSecs = Number(deadline1Hour)
      const deadline1DaySecs = Number(deadline1Day)

      // Check if deadlines are in the future
      if (deadline5MinSecs > currentTime && deadline5MinSecs < currentTime + 600) {
        console.log('✅ 5-minute deadline is reasonable')
      } else {
        console.log(`❌ 5-minute deadline is unreasonable: ${deadline5MinSecs}`)
        return false
      }

      if (deadline1HourSecs > currentTime + 3400 && deadline1HourSecs < currentTime + 3800) {
        console.log('✅ 1-hour deadline is reasonable')
      } else {
        console.log(`❌ 1-hour deadline is unreasonable: ${deadline1HourSecs}`)
        return false
      }

      if (deadline1DaySecs > currentTime + 86000 && deadline1DaySecs < currentTime + 87000) {
        console.log('✅ 1-day deadline is reasonable')
      } else {
        console.log(`❌ 1-day deadline is unreasonable: ${deadline1DaySecs}`)
        return false
      }

      return true
    } catch (error) {
      console.log(`❌ Nonce and deadline generation test failed: ${error}`)
      return false
    }
  }

  // Run all tests
  async runAllTests(): Promise<void> {
    console.log('🚀 Starting EIP-712 Signature Test Suite')
    console.log('==========================================')

    const testResults = {
      domain: await this.testDomainConfiguration(),
      types: await this.testTypeDefinitions(),
      generation: await this.testSignatureGeneration(),
      verification: await this.testSignatureVerification(),
      crossChain: await this.testCrossChainDomains(),
      manipulation: await this.testSignatureManipulation(),
      validation: await this.testValidationHelpers(),
      nonceDeadline: await this.testNonceAndDeadlineGeneration(),
    }

    console.log('\n📋 Test Results Summary')
    console.log('=======================')
    
    const passedTests = Object.values(testResults).filter(result => result === true).length
    const totalTests = Object.keys(testResults).length

    Object.entries(testResults).forEach(([testName, result]) => {
      const status = result ? '✅ PASS' : '❌ FAIL'
      console.log(`${status} ${testName}`)
    })

    console.log(`\n🎯 Overall Results: ${passedTests}/${totalTests} tests passed`)

    if (this.testSignatures.length > 0) {
      console.log(`\n📝 Generated ${this.testSignatures.length} test signatures for integration testing`)
    }

    console.log('\n🏁 EIP-712 Signature Test Suite Complete')
  }
}

// Run the tests
async function main() {
  const testSuite = new EIP712SignatureTestSuite()
  await testSuite.runAllTests()
}

if (require.main === module) {
  main().catch(console.error)
}

export { EIP712SignatureTestSuite }