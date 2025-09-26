#!/usr/bin/env node

import { privateKeyToAccount, generatePrivateKey } from 'viem/accounts'
import { createWalletClient, http, parseEther, formatEther } from 'viem'
import { baseSepolia } from 'viem/chains'
import {
  RedemptionAPI,
  RedemptionStatus,
  type CreateRedemptionRequestParams,
  type UpdateRedemptionStatusParams,
  type ProcessRedemptionParams
} from '../frontend/lib/redemption-api'
import {
  createRedemptionDomain,
  generateNonce,
  createDeadline,
  validateRedemptionRequest,
  REDEMPTION_TYPES,
  type RedemptionRequestData,
  type SignedRedemptionRequest
} from '../frontend/lib/eip712'

// Test configuration
const config = {
  apiBaseUrl: 'http://localhost:3000/api',
  chainId: 84532, // Base Sepolia
  vaultAddress: '0x742d35Cc6634C0532925a3b8D23dC6e74c4b8e1D' as `0x${string}`,
  deploymentId: 'cm43wuwdm0000zy7tqdbjdz5u', // Replace with actual deployment ID
  testUserPrivateKey: generatePrivateKey(),
}

// Test suite class
class RedemptionAPITestSuite {
  private api: RedemptionAPI
  private testUser: ReturnType<typeof privateKeyToAccount>
  private testRequestIds: string[] = []

  constructor() {
    this.api = new RedemptionAPI(config.apiBaseUrl)
    this.testUser = privateKeyToAccount(config.testUserPrivateKey)
    console.log(`🧪 Test User Address: ${this.testUser.address}`)
  }

  // Utility to create a test wallet client
  private createTestWallet() {
    return createWalletClient({
      account: this.testUser,
      chain: baseSepolia,
      transport: http()
    })
  }

  // Create a signed redemption request for testing
  private async createTestSignedRequest(
    shareAmount: bigint = parseEther('1'),
    minAssetsOut: bigint = parseEther('0.95')
  ): Promise<SignedRedemptionRequest> {
    const domain = createRedemptionDomain(config.chainId, config.vaultAddress)
    const nonce = generateNonce()
    const deadline = createDeadline(60) // 1 hour from now

    const requestData: RedemptionRequestData = {
      user: this.testUser.address,
      shareAmount,
      minAssetsOut,
      nonce,
      deadline
    }

    // Validate the request data
    const errors = validateRedemptionRequest(requestData)
    if (errors.length > 0) {
      throw new Error(`Invalid request data: ${errors.join(', ')}`)
    }

    const walletClient = this.createTestWallet()
    const signature = await walletClient.signTypedData({
      domain,
      types: REDEMPTION_TYPES,
      primaryType: 'RedemptionRequest',
      message: requestData
    })

    return {
      ...requestData,
      signature
    }
  }

  // Test 1: API Health Check
  async testAPIHealth(): Promise<boolean> {
    console.log('\n📊 Test 1: API Health Check')
    try {
      const stats = await this.api.getQueueStats()
      console.log('✅ API is responsive')
      console.log(`   Queue Stats: ${JSON.stringify(stats, null, 2)}`)
      return true
    } catch (error) {
      console.log(`❌ API Health Check failed: ${error}`)
      return false
    }
  }

  // Test 2: Submit Valid Redemption Request
  async testSubmitValidRedemption(): Promise<string | null> {
    console.log('\n📝 Test 2: Submit Valid Redemption Request')
    try {
      const signedRequest = await this.createTestSignedRequest()
      const expectedAssets = formatEther(parseEther('0.98')) // Expected asset amount

      const params: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets,
        signedRequest
      }

      const response = await this.api.submitRedemptionRequest(params)
      console.log('✅ Redemption request submitted successfully')
      console.log(`   Request ID: ${response.id}`)
      console.log(`   Status: ${response.status}`)
      console.log(`   User: ${response.userAddress}`)
      console.log(`   Share Amount: ${response.shareAmount}`)
      console.log(`   Expected Assets: ${response.expectedAssets}`)

      this.testRequestIds.push(response.id)
      return response.id
    } catch (error) {
      console.log(`❌ Submit valid redemption failed: ${error}`)
      return null
    }
  }

  // Test 3: Submit Invalid Redemption Requests
  async testSubmitInvalidRedemptions(): Promise<boolean> {
    console.log('\n🚫 Test 3: Submit Invalid Redemption Requests')
    let allTestsPassed = true

    // Test 3a: Invalid signature
    try {
      const signedRequest = await this.createTestSignedRequest()
      signedRequest.signature = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b'

      await this.api.submitRedemptionRequest({
        deploymentId: config.deploymentId,
        expectedAssets: '1000000000000000000',
        signedRequest
      })
      
      console.log('❌ Should have failed with invalid signature')
      allTestsPassed = false
    } catch (error) {
      console.log('✅ Invalid signature correctly rejected')
    }

    // Test 3b: Duplicate nonce
    try {
      const signedRequest = await this.createTestSignedRequest()
      const params = {
        deploymentId: config.deploymentId,
        expectedAssets: '1000000000000000000',
        signedRequest
      }

      await this.api.submitRedemptionRequest(params)
      await this.api.submitRedemptionRequest(params) // Should fail on duplicate nonce
      
      console.log('❌ Should have failed with duplicate nonce')
      allTestsPassed = false
    } catch (error) {
      console.log('✅ Duplicate nonce correctly rejected')
    }

    // Test 3c: Expired signature
    try {
      const domain = createRedemptionDomain(config.chainId, config.vaultAddress)
      const expiredDeadline = BigInt(Math.floor(Date.now() / 1000) - 3600) // 1 hour ago

      const requestData: RedemptionRequestData = {
        user: this.testUser.address,
        shareAmount: parseEther('1'),
        minAssetsOut: parseEther('0.95'),
        nonce: generateNonce(),
        deadline: expiredDeadline
      }

      const walletClient = this.createTestWallet()
      const signature = await walletClient.signTypedData({
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData
      })

      const signedRequest = { ...requestData, signature }

      await this.api.submitRedemptionRequest({
        deploymentId: config.deploymentId,
        expectedAssets: '1000000000000000000',
        signedRequest
      })
      
      console.log('❌ Should have failed with expired signature')
      allTestsPassed = false
    } catch (error) {
      console.log('✅ Expired signature correctly rejected')
    }

    return allTestsPassed
  }

  // Test 4: Retrieve Redemption Requests
  async testRetrieveRedemptions(): Promise<boolean> {
    console.log('\n🔍 Test 4: Retrieve Redemption Requests')
    try {
      // Test get all requests
      const allRequests = await this.api.getRedemptionRequests()
      console.log(`✅ Retrieved ${allRequests.requests.length} total requests`)
      console.log(`   Total Count: ${allRequests.totalCount}`)
      console.log(`   Page: ${allRequests.page}, Limit: ${allRequests.limit}`)

      // Test get requests by user
      const userRequests = await this.api.getUserRedemptions(this.testUser.address)
      console.log(`✅ Retrieved ${userRequests.requests.length} user requests`)

      // Test get requests by status
      const pendingRequests = await this.api.getRedemptionRequests({
        status: [RedemptionStatus.PENDING]
      })
      console.log(`✅ Retrieved ${pendingRequests.requests.length} pending requests`)

      // Test get specific request
      if (this.testRequestIds.length > 0) {
        const specificRequest = await this.api.getRedemptionRequest(this.testRequestIds[0])
        console.log(`✅ Retrieved specific request: ${specificRequest.id}`)
      }

      return true
    } catch (error) {
      console.log(`❌ Retrieve redemptions failed: ${error}`)
      return false
    }
  }

  // Test 5: Admin Status Updates
  async testAdminStatusUpdates(): Promise<boolean> {
    console.log('\n👑 Test 5: Admin Status Updates')
    let allTestsPassed = true

    if (this.testRequestIds.length === 0) {
      console.log('⚠️  No test requests available for status updates')
      return false
    }

    const requestId = this.testRequestIds[0]

    try {
      // Test approve request
      const approveParams: UpdateRedemptionStatusParams = {
        id: requestId,
        status: RedemptionStatus.APPROVED,
        adminNotes: 'Test approval',
        priority: 1
      }

      const approvedRequest = await this.api.updateRedemptionStatus(approveParams)
      console.log(`✅ Request approved: ${approvedRequest.status}`)
      console.log(`   Queue Position: ${approvedRequest.queuePosition}`)

      // Test move to processing
      const processingParams: UpdateRedemptionStatusParams = {
        id: requestId,
        status: RedemptionStatus.PROCESSING,
        adminNotes: 'Starting processing'
      }

      const processingRequest = await this.api.updateRedemptionStatus(processingParams)
      console.log(`✅ Request moved to processing: ${processingRequest.status}`)

      // Test mark as processed
      const processParams: ProcessRedemptionParams = {
        id: requestId,
        txHash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        actualAssets: '980000000000000000',
        gasCost: '50000000000000000'
      }

      const processedRequest = await this.api.markRedemptionProcessed(processParams)
      console.log(`✅ Request marked as processed: ${processedRequest.status}`)
      console.log(`   TX Hash: ${processedRequest.txHash}`)
      console.log(`   Actual Assets: ${processedRequest.actualAssets}`)

    } catch (error) {
      console.log(`❌ Admin status updates failed: ${error}`)
      allTestsPassed = false
    }

    return allTestsPassed
  }

  // Test 6: Cancel Redemption
  async testCancelRedemption(): Promise<boolean> {
    console.log('\n🚫 Test 6: Cancel Redemption')
    try {
      // Create a new request specifically for cancellation
      const signedRequest = await this.createTestSignedRequest()
      const params: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: '1000000000000000000',
        signedRequest
      }

      const createdRequest = await this.api.submitRedemptionRequest(params)
      console.log(`✅ Created request for cancellation: ${createdRequest.id}`)

      // Cancel the request
      const cancelledRequest = await this.api.cancelRedemptionRequest(
        createdRequest.id,
        'User requested cancellation'
      )
      console.log(`✅ Request cancelled: ${cancelledRequest.status}`)

      return true
    } catch (error) {
      console.log(`❌ Cancel redemption failed: ${error}`)
      return false
    }
  }

  // Test 7: Queue Statistics
  async testQueueStatistics(): Promise<boolean> {
    console.log('\n📊 Test 7: Queue Statistics')
    try {
      // Get overall stats
      const overallStats = await this.api.getQueueStats()
      console.log('✅ Overall Queue Stats:')
      console.log(`   Total Requests: ${overallStats.totalRequests}`)
      console.log(`   Pending: ${overallStats.pendingRequests}`)
      console.log(`   Approved: ${overallStats.approvedRequests}`)
      console.log(`   Processing: ${overallStats.processingRequests}`)
      console.log(`   Completed: ${overallStats.completedRequests}`)
      console.log(`   Failed: ${overallStats.failedRequests}`)
      console.log(`   Queue Length: ${overallStats.queueLength}`)
      console.log(`   Avg Processing Time: ${overallStats.averageProcessingTime}s`)

      // Get deployment-specific stats
      const deploymentStats = await this.api.getQueueStats(config.deploymentId)
      console.log(`✅ Deployment ${config.deploymentId} Stats:`)
      console.log(`   Total Requests: ${deploymentStats.totalRequests}`)
      console.log(`   Queue Length: ${deploymentStats.queueLength}`)

      return true
    } catch (error) {
      console.log(`❌ Queue statistics failed: ${error}`)
      return false
    }
  }

  // Test 8: Error Handling
  async testErrorHandling(): Promise<boolean> {
    console.log('\n🛠️  Test 8: Error Handling')
    let allTestsPassed = true

    try {
      // Test non-existent request
      await this.api.getRedemptionRequest('non-existent-id')
      console.log('❌ Should have failed with non-existent request')
      allTestsPassed = false
    } catch (error) {
      console.log('✅ Non-existent request correctly handled')
    }

    try {
      // Test invalid status update
      await this.api.updateRedemptionStatus({
        id: 'non-existent-id',
        status: 'INVALID_STATUS' as any,
      })
      console.log('❌ Should have failed with invalid status')
      allTestsPassed = false
    } catch (error) {
      console.log('✅ Invalid status correctly rejected')
    }

    return allTestsPassed
  }

  // Run all tests
  async runAllTests(): Promise<void> {
    console.log('🚀 Starting Comprehensive Redemption API Test Suite')
    console.log('==================================================')

    const testResults = {
      apiHealth: await this.testAPIHealth(),
      submitValid: await this.testSubmitValidRedemption(),
      submitInvalid: await this.testSubmitInvalidRedemptions(),
      retrieve: await this.testRetrieveRedemptions(),
      adminUpdates: await this.testAdminStatusUpdates(),
      cancel: await this.testCancelRedemption(),
      statistics: await this.testQueueStatistics(),
      errorHandling: await this.testErrorHandling(),
    }

    console.log('\n📋 Test Results Summary')
    console.log('=======================')
    
    const passedTests = Object.values(testResults).filter(result => 
      result === true || typeof result === 'string'
    ).length
    const totalTests = Object.keys(testResults).length

    Object.entries(testResults).forEach(([testName, result]) => {
      const status = (result === true || typeof result === 'string') ? '✅ PASS' : '❌ FAIL'
      console.log(`${status} ${testName}`)
    })

    console.log(`\n🎯 Overall Results: ${passedTests}/${totalTests} tests passed`)
    
    if (this.testRequestIds.length > 0) {
      console.log(`\n📝 Test Request IDs created: ${this.testRequestIds.join(', ')}`)
    }

    console.log('\n🏁 Test Suite Complete')
  }
}

// Run the tests
async function main() {
  const testSuite = new RedemptionAPITestSuite()
  await testSuite.runAllTests()
}

if (require.main === module) {
  main().catch(console.error)
}

export { RedemptionAPITestSuite }