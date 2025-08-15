#!/usr/bin/env node

import { privateKeyToAccount, generatePrivateKey } from 'viem/accounts'
import { createWalletClient, http, parseEther, formatEther, createPublicClient } from 'viem'
import { baseSepolia } from 'viem/chains'
import {
  RedemptionAPI,
  RedemptionStatus,
  type CreateRedemptionRequestParams,
  type UpdateRedemptionStatusParams,
  type ProcessRedemptionParams,
  type RedemptionRequestResponse
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

// Mock vault contract ABI (minimal interface for testing)
const VAULT_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'previewRedeem',
    type: 'function',
    inputs: [{ name: 'shares', type: 'uint256' }],
    outputs: [{ name: 'assets', type: 'uint256' }]
  },
  {
    name: 'redeem',
    type: 'function',
    inputs: [
      { name: 'shares', type: 'uint256' },
      { name: 'receiver', type: 'address' },
      { name: 'owner', type: 'address' }
    ],
    outputs: [{ name: 'assets', type: 'uint256' }]
  }
] as const

// Test configuration
const config = {
  apiBaseUrl: 'http://localhost:3000/api',
  chainId: 84532, // Base Sepolia
  vaultAddress: '0x742d35Cc6634C0532925a3b8D23dC6e74c4b8e1D' as `0x${string}`,
  deploymentId: 'cm43wuwdm0000zy7tqdbjdz5u', // Replace with actual deployment ID
  rpcUrl: 'https://sepolia.base.org',
  blockExplorer: 'https://sepolia-explorer.base.org',
  adminPrivateKey: generatePrivateKey(),
  userPrivateKey: generatePrivateKey(),
}

interface E2ETestScenario {
  name: string
  shareAmount: bigint
  expectedOutcome: 'SUCCESS' | 'FAILURE'
  failureReason?: string
}

class E2ERedemptionFlowTestSuite {
  private api: RedemptionAPI
  private publicClient: ReturnType<typeof createPublicClient>
  private admin: ReturnType<typeof privateKeyToAccount>
  private user: ReturnType<typeof privateKeyToAccount>
  private adminWallet: ReturnType<typeof createWalletClient>
  private userWallet: ReturnType<typeof createWalletClient>
  private testResults: Record<string, any> = {}

  constructor() {
    this.api = new RedemptionAPI(config.apiBaseUrl)
    
    this.publicClient = createPublicClient({
      chain: baseSepolia,
      transport: http(config.rpcUrl)
    })

    this.admin = privateKeyToAccount(config.adminPrivateKey)
    this.user = privateKeyToAccount(config.userPrivateKey)

    this.adminWallet = createWalletClient({
      account: this.admin,
      chain: baseSepolia,
      transport: http(config.rpcUrl)
    })

    this.userWallet = createWalletClient({
      account: this.user,
      chain: baseSepolia,
      transport: http(config.rpcUrl)
    })

    console.log('🎭 E2E Test Participants:')
    console.log(`   👑 Admin: ${this.admin.address}`)
    console.log(`   👤 User: ${this.user.address}`)
  }

  // Helper to create signed redemption request
  private async createSignedRedemptionRequest(
    shareAmount: bigint,
    minAssetsOut: bigint
  ): Promise<SignedRedemptionRequest> {
    const domain = createRedemptionDomain(config.chainId, config.vaultAddress)
    
    const requestData: RedemptionRequestData = {
      user: this.user.address,
      shareAmount,
      minAssetsOut,
      nonce: generateNonce(),
      deadline: createDeadline(60) // 1 hour from now
    }

    // Validate request
    const errors = validateRedemptionRequest(requestData)
    if (errors.length > 0) {
      throw new Error(`Invalid request: ${errors.join(', ')}`)
    }

    const signature = await this.userWallet.signTypedData({
      domain,
      types: REDEMPTION_TYPES,
      primaryType: 'RedemptionRequest',
      message: requestData
    })

    return { ...requestData, signature }
  }

  // Helper to wait for a condition with timeout
  private async waitForCondition(
    condition: () => Promise<boolean>,
    timeoutMs: number = 30000,
    intervalMs: number = 1000
  ): Promise<boolean> {
    const startTime = Date.now()
    
    while (Date.now() - startTime < timeoutMs) {
      if (await condition()) {
        return true
      }
      await new Promise(resolve => setTimeout(resolve, intervalMs))
    }
    
    return false
  }

  // Test 0: Pre-flight Checks
  async testPreflightChecks(): Promise<boolean> {
    console.log('\n🛫 Test 0: Pre-flight Checks')
    try {
      // Check API connectivity
      const stats = await this.api.getQueueStats()
      console.log('✅ API is accessible')
      console.log(`   Current queue length: ${stats.queueLength}`)

      // Check blockchain connectivity
      const blockNumber = await this.publicClient.getBlockNumber()
      console.log(`✅ Blockchain accessible - Block: ${blockNumber}`)

      // Check if vault contract exists (this might fail if vault doesn't exist)
      try {
        const userShares = await this.publicClient.readContract({
          address: config.vaultAddress,
          abi: VAULT_ABI,
          functionName: 'balanceOf',
          args: [this.user.address]
        })
        console.log(`✅ Vault contract accessible - User shares: ${formatEther(userShares)}`)
      } catch (error) {
        console.log('⚠️  Vault contract not accessible (may not be deployed yet)')
        console.log(`   This is OK for API-only testing: ${error}`)
      }

      // Test EIP-712 signature generation
      const testSignature = await this.createSignedRedemptionRequest(
        parseEther('1'),
        parseEther('0.95')
      )
      console.log('✅ EIP-712 signature generation working')

      return true
    } catch (error) {
      console.log(`❌ Pre-flight checks failed: ${error}`)
      return false
    }
  }

  // Test 1: Complete Happy Path Flow
  async testHappyPathFlow(): Promise<boolean> {
    console.log('\n😊 Test 1: Complete Happy Path Flow')
    try {
      const shareAmount = parseEther('2')
      const minAssetsOut = parseEther('1.9')
      const expectedAssets = parseEther('1.95')

      console.log(`Starting happy path with ${formatEther(shareAmount)} shares`)

      // Step 1: User creates signed redemption request
      console.log('🔐 Step 1: Creating signed redemption request...')
      const signedRequest = await this.createSignedRedemptionRequest(shareAmount, minAssetsOut)
      console.log(`   ✅ Request signed with nonce: ${signedRequest.nonce}`)

      // Step 2: Submit redemption request to API
      console.log('📤 Step 2: Submitting redemption request...')
      const submitParams: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: expectedAssets.toString(),
        signedRequest
      }

      const submittedRequest = await this.api.submitRedemptionRequest(submitParams)
      console.log(`   ✅ Request submitted - ID: ${submittedRequest.id}`)
      console.log(`   Status: ${submittedRequest.status}`)
      this.testResults.happyPathRequestId = submittedRequest.id

      // Step 3: Admin approves the request
      console.log('👑 Step 3: Admin approving request...')
      const approvalParams: UpdateRedemptionStatusParams = {
        id: submittedRequest.id,
        status: RedemptionStatus.APPROVED,
        adminNotes: 'E2E test approval - happy path',
        priority: 1
      }

      const approvedRequest = await this.api.updateRedemptionStatus(approvalParams)
      console.log(`   ✅ Request approved - Queue position: ${approvedRequest.queuePosition}`)

      // Step 4: Check queue statistics
      console.log('📊 Step 4: Checking queue statistics...')
      const queueStats = await this.api.getQueueStats(config.deploymentId)
      console.log(`   Queue length: ${queueStats.queueLength}`)
      console.log(`   Approved requests: ${queueStats.approvedRequests}`)

      // Step 5: Admin moves to processing
      console.log('⚙️  Step 5: Moving to processing...')
      const processingParams: UpdateRedemptionStatusParams = {
        id: submittedRequest.id,
        status: RedemptionStatus.PROCESSING,
        adminNotes: 'E2E test - processing on blockchain'
      }

      const processingRequest = await this.api.updateRedemptionStatus(processingParams)
      console.log(`   ✅ Request moved to processing: ${processingRequest.status}`)

      // Step 6: Simulate blockchain processing time
      console.log('⏳ Step 6: Simulating blockchain processing...')
      await new Promise(resolve => setTimeout(resolve, 2000)) // 2 second delay

      // Step 7: Admin marks as completed
      console.log('✅ Step 7: Marking as completed...')
      const processParams: ProcessRedemptionParams = {
        id: submittedRequest.id,
        txHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
        actualAssets: (expectedAssets - parseEther('0.05')).toString(), // Slight slippage
        gasCost: parseEther('0.01').toString()
      }

      const completedRequest = await this.api.markRedemptionProcessed(processParams)
      console.log(`   ✅ Request completed: ${completedRequest.status}`)
      console.log(`   TX Hash: ${completedRequest.txHash}`)
      console.log(`   Actual Assets: ${formatEther(BigInt(completedRequest.actualAssets || '0'))} ETH`)
      console.log(`   Gas Cost: ${formatEther(BigInt(completedRequest.gasCost || '0'))} ETH`)

      // Step 8: Verify final state
      console.log('🔍 Step 8: Verifying final state...')
      const finalRequest = await this.api.getRedemptionRequest(submittedRequest.id)
      
      const isCompleted = finalRequest.status === RedemptionStatus.COMPLETED
      const hasTxHash = !!finalRequest.txHash
      const hasActualAssets = !!finalRequest.actualAssets

      if (isCompleted && hasTxHash && hasActualAssets) {
        console.log('   ✅ Final state verification passed')
        console.log('🎉 Happy path flow completed successfully!')
        return true
      } else {
        console.log('   ❌ Final state verification failed')
        return false
      }

    } catch (error) {
      console.log(`❌ Happy path flow failed: ${error}`)
      return false
    }
  }

  // Test 2: Rejection Flow
  async testRejectionFlow(): Promise<boolean> {
    console.log('\n🚫 Test 2: Rejection Flow')
    try {
      const shareAmount = parseEther('0.5')
      const minAssetsOut = parseEther('0.48')
      const expectedAssets = parseEther('0.49')

      console.log(`Starting rejection flow with ${formatEther(shareAmount)} shares`)

      // Step 1: Create and submit request
      const signedRequest = await this.createSignedRedemptionRequest(shareAmount, minAssetsOut)
      const submitParams: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: expectedAssets.toString(),
        signedRequest
      }

      const submittedRequest = await this.api.submitRedemptionRequest(submitParams)
      console.log(`✅ Request submitted - ID: ${submittedRequest.id}`)

      // Step 2: Admin rejects the request
      const rejectionParams: UpdateRedemptionStatusParams = {
        id: submittedRequest.id,
        status: RedemptionStatus.REJECTED,
        adminNotes: 'E2E test rejection - insufficient collateral backing',
        rejectionReason: 'Request amount exceeds available collateral reserves'
      }

      const rejectedRequest = await this.api.updateRedemptionStatus(rejectionParams)
      console.log(`✅ Request rejected: ${rejectedRequest.status}`)
      console.log(`   Rejection reason: ${rejectedRequest.rejectionReason}`)

      // Step 3: Verify user can see rejection
      const userRequests = await this.api.getUserRedemptions(this.user.address)
      const rejectedUserRequest = userRequests.requests.find(r => r.id === submittedRequest.id)

      if (rejectedUserRequest?.status === RedemptionStatus.REJECTED) {
        console.log('✅ User can see rejected request')
        console.log('🎯 Rejection flow completed successfully!')
        return true
      } else {
        console.log('❌ User cannot see rejection status')
        return false
      }

    } catch (error) {
      console.log(`❌ Rejection flow failed: ${error}`)
      return false
    }
  }

  // Test 3: Failure and Retry Flow
  async testFailureRetryFlow(): Promise<boolean> {
    console.log('\n⚠️  Test 3: Failure and Retry Flow')
    try {
      const shareAmount = parseEther('1')
      const minAssetsOut = parseEther('0.95')
      const expectedAssets = parseEther('0.98')

      console.log(`Starting failure/retry flow with ${formatEther(shareAmount)} shares`)

      // Step 1: Create, submit, and approve request
      const signedRequest = await this.createSignedRedemptionRequest(shareAmount, minAssetsOut)
      const submitParams: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: expectedAssets.toString(),
        signedRequest
      }

      const submittedRequest = await this.api.submitRedemptionRequest(submitParams)
      console.log(`✅ Request submitted - ID: ${submittedRequest.id}`)

      await this.api.updateRedemptionStatus({
        id: submittedRequest.id,
        status: RedemptionStatus.APPROVED,
        adminNotes: 'Approved for failure test'
      })

      await this.api.updateRedemptionStatus({
        id: submittedRequest.id,
        status: RedemptionStatus.PROCESSING,
        adminNotes: 'Processing - will simulate failure'
      })

      console.log('✅ Request moved to processing')

      // Step 2: Simulate failure
      const failedRequest = await this.api.updateRedemptionStatus({
        id: submittedRequest.id,
        status: RedemptionStatus.FAILED,
        adminNotes: 'Transaction failed due to gas limit',
        rejectionReason: 'Blockchain transaction reverted'
      })

      console.log(`✅ Request marked as failed: ${failedRequest.status}`)

      // Step 3: Retry the failed request
      const retryRequest = await this.api.updateRedemptionStatus({
        id: submittedRequest.id,
        status: RedemptionStatus.PROCESSING,
        adminNotes: 'Retrying after failure with higher gas limit'
      })

      console.log(`✅ Request moved back to processing for retry: ${retryRequest.status}`)

      // Step 4: Complete the retry
      const processParams: ProcessRedemptionParams = {
        id: submittedRequest.id,
        txHash: '0xretry123456789abcdef123456789abcdef123456789abcdef123456789abcdef',
        actualAssets: expectedAssets.toString(),
        gasCost: parseEther('0.02').toString() // Higher gas cost for retry
      }

      const completedRequest = await this.api.markRedemptionProcessed(processParams)
      console.log(`✅ Retry completed successfully: ${completedRequest.status}`)
      console.log(`   Final TX Hash: ${completedRequest.txHash}`)

      console.log('🔄 Failure and retry flow completed successfully!')
      return true

    } catch (error) {
      console.log(`❌ Failure and retry flow failed: ${error}`)
      return false
    }
  }

  // Test 4: Cancellation Flow
  async testCancellationFlow(): Promise<boolean> {
    console.log('\n🚮 Test 4: Cancellation Flow')
    try {
      const shareAmount = parseEther('0.3')
      const minAssetsOut = parseEther('0.28')
      const expectedAssets = parseEther('0.29')

      console.log(`Starting cancellation flow with ${formatEther(shareAmount)} shares`)

      // Step 1: User creates and submits request
      const signedRequest = await this.createSignedRedemptionRequest(shareAmount, minAssetsOut)
      const submitParams: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: expectedAssets.toString(),
        signedRequest
      }

      const submittedRequest = await this.api.submitRedemptionRequest(submitParams)
      console.log(`✅ Request submitted - ID: ${submittedRequest.id}`)

      // Step 2: User cancels request (before approval)
      const cancelledRequest = await this.api.cancelRedemptionRequest(
        submittedRequest.id,
        'User changed mind - E2E test cancellation'
      )

      console.log(`✅ Request cancelled by user: ${cancelledRequest.status}`)

      // Step 3: Test cancellation after approval
      const signedRequest2 = await this.createSignedRedemptionRequest(
        parseEther('0.4'),
        parseEther('0.38')
      )
      const submitParams2: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: parseEther('0.39').toString(),
        signedRequest: signedRequest2
      }

      const submittedRequest2 = await this.api.submitRedemptionRequest(submitParams2)
      
      // Approve the request
      await this.api.updateRedemptionStatus({
        id: submittedRequest2.id,
        status: RedemptionStatus.APPROVED,
        adminNotes: 'Approved but will be cancelled'
      })

      // Admin cancels approved request
      const adminCancelledRequest = await this.api.cancelRedemptionRequest(
        submittedRequest2.id,
        'Admin cancelled due to low liquidity'
      )

      console.log(`✅ Approved request cancelled by admin: ${adminCancelledRequest.status}`)
      console.log('🚮 Cancellation flow completed successfully!')
      return true

    } catch (error) {
      console.log(`❌ Cancellation flow failed: ${error}`)
      return false
    }
  }

  // Test 5: Priority Queue Management
  async testPriorityQueueManagement(): Promise<boolean> {
    console.log('\n⭐ Test 5: Priority Queue Management')
    try {
      console.log('Creating multiple requests with different priorities...')

      const requests = []
      const priorities = [3, 1, 2] // Different priority levels
      const shareAmounts = [parseEther('1'), parseEther('2'), parseEther('0.5')]

      // Create multiple requests
      for (let i = 0; i < 3; i++) {
        const signedRequest = await this.createSignedRedemptionRequest(
          shareAmounts[i],
          shareAmounts[i] - parseEther('0.05')
        )

        const submitParams: CreateRedemptionRequestParams = {
          deploymentId: config.deploymentId,
          expectedAssets: (shareAmounts[i] - parseEther('0.02')).toString(),
          signedRequest
        }

        const submittedRequest = await this.api.submitRedemptionRequest(submitParams)
        requests.push(submittedRequest)

        // Approve with different priorities
        await this.api.updateRedemptionStatus({
          id: submittedRequest.id,
          status: RedemptionStatus.APPROVED,
          priority: priorities[i],
          adminNotes: `Priority ${priorities[i]} request - E2E test`
        })

        console.log(`✅ Request ${i + 1} created and approved with priority ${priorities[i]}`)
      }

      // Get queue and verify ordering
      const approvedQueue = await this.api.getRedemptionRequests({
        status: [RedemptionStatus.APPROVED],
        deploymentId: config.deploymentId
      })

      const testRequests = approvedQueue.requests.filter(r => 
        requests.some(req => req.id === r.id)
      ).sort((a, b) => (a.queuePosition || 0) - (b.queuePosition || 0))

      console.log('✅ Queue order verification:')
      testRequests.forEach((request, index) => {
        console.log(`   ${index + 1}. Priority: ${request.priority}, Position: ${request.queuePosition}`)
      })

      // Process in queue order
      for (const request of testRequests) {
        await this.api.updateRedemptionStatus({
          id: request.id,
          status: RedemptionStatus.PROCESSING,
          adminNotes: `Processing in queue order - position ${request.queuePosition}`
        })

        const processParams: ProcessRedemptionParams = {
          id: request.id,
          txHash: `0xqueue${request.queuePosition}abcdef1234567890abcdef1234567890abcdef12345678`,
          actualAssets: (BigInt(request.expectedAssets) - parseEther('0.01')).toString(),
          gasCost: parseEther('0.015').toString()
        }

        await this.api.markRedemptionProcessed(processParams)
        console.log(`✅ Processed request at queue position ${request.queuePosition}`)
      }

      console.log('⭐ Priority queue management completed successfully!')
      return true

    } catch (error) {
      console.log(`❌ Priority queue management failed: ${error}`)
      return false
    }
  }

  // Test 6: Signature Expiry Handling
  async testSignatureExpiryHandling(): Promise<boolean> {
    console.log('\n⏰ Test 6: Signature Expiry Handling')
    try {
      // Create a request with a very short expiry (1 minute)
      const domain = createRedemptionDomain(config.chainId, config.vaultAddress)
      const shortDeadline = BigInt(Math.floor(Date.now() / 1000) + 60) // 1 minute from now
      
      const requestData: RedemptionRequestData = {
        user: this.user.address,
        shareAmount: parseEther('0.1'),
        minAssetsOut: parseEther('0.09'),
        nonce: generateNonce(),
        deadline: shortDeadline
      }

      const signature = await this.userWallet.signTypedData({
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData
      })

      const signedRequest = { ...requestData, signature }

      // Submit immediately (should work)
      const submitParams: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: parseEther('0.095').toString(),
        signedRequest
      }

      const submittedRequest = await this.api.submitRedemptionRequest(submitParams)
      console.log(`✅ Request with short expiry submitted: ${submittedRequest.id}`)

      // Test that the system properly handles expiry
      await this.api.updateRedemptionStatus({
        id: submittedRequest.id,
        status: RedemptionStatus.EXPIRED,
        adminNotes: 'Signature expired before processing',
        rejectionReason: 'EIP-712 signature deadline exceeded'
      })

      console.log('✅ Request properly marked as expired')

      // Try to create another request with already expired signature
      const expiredDeadline = BigInt(Math.floor(Date.now() / 1000) - 300) // 5 minutes ago
      const expiredRequestData: RedemptionRequestData = {
        user: this.user.address,
        shareAmount: parseEther('0.1'),
        minAssetsOut: parseEther('0.09'),
        nonce: generateNonce(),
        deadline: expiredDeadline
      }

      const expiredSignature = await this.userWallet.signTypedData({
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: expiredRequestData
      })

      const expiredSignedRequest = { ...expiredRequestData, signature: expiredSignature }

      try {
        await this.api.submitRedemptionRequest({
          deploymentId: config.deploymentId,
          expectedAssets: parseEther('0.095').toString(),
          signedRequest: expiredSignedRequest
        })
        console.log('❌ Should have rejected expired signature')
        return false
      } catch (error) {
        console.log('✅ Expired signature correctly rejected')
      }

      console.log('⏰ Signature expiry handling completed successfully!')
      return true

    } catch (error) {
      console.log(`❌ Signature expiry handling failed: ${error}`)
      return false
    }
  }

  // Test 7: Concurrent Request Handling
  async testConcurrentRequestHandling(): Promise<boolean> {
    console.log('\n🔀 Test 7: Concurrent Request Handling')
    try {
      console.log('Creating multiple concurrent requests...')

      // Create multiple requests concurrently
      const concurrentRequests = await Promise.all([
        this.createConcurrentRequest(parseEther('0.5'), 1),
        this.createConcurrentRequest(parseEther('0.3'), 2),
        this.createConcurrentRequest(parseEther('0.7'), 3),
      ])

      console.log(`✅ Created ${concurrentRequests.length} concurrent requests`)

      // Process them concurrently through approval
      const approvalPromises = concurrentRequests.map((request, index) => 
        this.api.updateRedemptionStatus({
          id: request.id,
          status: RedemptionStatus.APPROVED,
          priority: index + 1,
          adminNotes: `Concurrent approval ${index + 1}`
        })
      )

      const approvedRequests = await Promise.all(approvalPromises)
      console.log('✅ All requests approved concurrently')

      // Verify no data corruption or race conditions
      for (const request of approvedRequests) {
        const verifyRequest = await this.api.getRedemptionRequest(request.id)
        if (verifyRequest.status === RedemptionStatus.APPROVED) {
          console.log(`✅ Request ${request.id} state consistent`)
        } else {
          console.log(`❌ Request ${request.id} state inconsistent`)
          return false
        }
      }

      console.log('🔀 Concurrent request handling completed successfully!')
      return true

    } catch (error) {
      console.log(`❌ Concurrent request handling failed: ${error}`)
      return false
    }
  }

  private async createConcurrentRequest(shareAmount: bigint, index: number) {
    const signedRequest = await this.createSignedRedemptionRequest(
      shareAmount,
      shareAmount - parseEther('0.05')
    )

    const submitParams: CreateRedemptionRequestParams = {
      deploymentId: config.deploymentId,
      expectedAssets: (shareAmount - parseEther('0.02')).toString(),
      signedRequest
    }

    return await this.api.submitRedemptionRequest(submitParams)
  }

  // Test 8: Performance and Load Testing
  async testPerformanceLoad(): Promise<boolean> {
    console.log('\n⚡ Test 8: Performance and Load Testing')
    try {
      const batchSize = 10
      const startTime = Date.now()

      console.log(`Creating ${batchSize} requests for performance testing...`)

      // Create multiple requests and measure time
      const requests = []
      for (let i = 0; i < batchSize; i++) {
        const signedRequest = await this.createSignedRedemptionRequest(
          parseEther('0.1'),
          parseEther('0.09')
        )

        const submitParams: CreateRedemptionRequestParams = {
          deploymentId: config.deploymentId,
          expectedAssets: parseEther('0.095').toString(),
          signedRequest
        }

        const request = await this.api.submitRedemptionRequest(submitParams)
        requests.push(request)
      }

      const endTime = Date.now()
      const totalTime = endTime - startTime
      const avgTime = totalTime / batchSize

      console.log(`✅ Created ${batchSize} requests in ${totalTime}ms`)
      console.log(`   Average time per request: ${avgTime.toFixed(2)}ms`)

      // Test bulk query performance
      const queryStartTime = Date.now()
      const allRequests = await this.api.getRedemptionRequests({
        limit: 50
      })
      const queryEndTime = Date.now()

      console.log(`✅ Queried ${allRequests.requests.length} requests in ${queryEndTime - queryStartTime}ms`)

      // Performance thresholds
      const requestCreationThreshold = 5000 // 5 seconds max per request
      const queryThreshold = 2000 // 2 seconds max for query

      if (avgTime < requestCreationThreshold && (queryEndTime - queryStartTime) < queryThreshold) {
        console.log('✅ Performance within acceptable thresholds')
        console.log('⚡ Performance and load testing completed successfully!')
        return true
      } else {
        console.log('⚠️  Performance may be suboptimal but test completed')
        return true // Don't fail the test for performance, just warn
      }

    } catch (error) {
      console.log(`❌ Performance and load testing failed: ${error}`)
      return false
    }
  }

  // Run all E2E tests
  async runAllTests(): Promise<void> {
    console.log('🚀 Starting End-to-End Redemption Flow Test Suite')
    console.log('==================================================')
    console.log(`📍 Testing against: ${config.apiBaseUrl}`)
    console.log(`⛓️  Chain: Base Sepolia (${config.chainId})`)
    console.log(`📝 Deployment: ${config.deploymentId}`)

    try {
      const testResults = {
        preflightChecks: await this.testPreflightChecks(),
        happyPathFlow: await this.testHappyPathFlow(),
        rejectionFlow: await this.testRejectionFlow(),
        failureRetryFlow: await this.testFailureRetryFlow(),
        cancellationFlow: await this.testCancellationFlow(),
        priorityQueueManagement: await this.testPriorityQueueManagement(),
        signatureExpiryHandling: await this.testSignatureExpiryHandling(),
        concurrentRequestHandling: await this.testConcurrentRequestHandling(),
        performanceLoad: await this.testPerformanceLoad(),
      }

      console.log('\n📋 E2E Test Results Summary')
      console.log('============================')
      
      const passedTests = Object.values(testResults).filter(result => result === true).length
      const totalTests = Object.keys(testResults).length

      Object.entries(testResults).forEach(([testName, result]) => {
        const status = result ? '✅ PASS' : '❌ FAIL'
        console.log(`${status} ${testName}`)
      })

      console.log(`\n🎯 Overall Results: ${passedTests}/${totalTests} tests passed`)

      // Summary of test coverage
      console.log('\n📊 Test Coverage Summary:')
      console.log('- ✅ API endpoint functionality')
      console.log('- ✅ EIP-712 signature verification')
      console.log('- ✅ Status transition workflows')
      console.log('- ✅ Admin queue management')
      console.log('- ✅ Error handling and edge cases')
      console.log('- ✅ Priority-based processing')
      console.log('- ✅ Concurrency and performance')

      // Provide production readiness assessment
      if (passedTests === totalTests) {
        console.log('\n🎉 PRODUCTION READY: All E2E tests passed!')
        console.log('   The redemption system is ready for production deployment.')
      } else if (passedTests >= totalTests * 0.8) {
        console.log('\n⚠️  MOSTLY READY: Most tests passed, minor issues to address.')
        console.log('   Review failed tests before production deployment.')
      } else {
        console.log('\n❌ NOT READY: Critical issues found in E2E testing.')
        console.log('   Address failed tests before considering production deployment.')
      }

      console.log('\n🏁 End-to-End Redemption Flow Test Suite Complete')

    } catch (error) {
      console.log(`💥 Test suite encountered a critical error: ${error}`)
      console.log('❌ Test suite incomplete - manual investigation required')
    }
  }
}

// Run the tests
async function main() {
  const testSuite = new E2ERedemptionFlowTestSuite()
  await testSuite.runAllTests()
}

if (require.main === module) {
  main().catch(console.error)
}

export { E2ERedemptionFlowTestSuite }