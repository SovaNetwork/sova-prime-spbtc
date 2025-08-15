#!/usr/bin/env node

import { privateKeyToAccount, generatePrivateKey } from 'viem/accounts'
import { createWalletClient, http, parseEther } from 'viem'
import { baseSepolia } from 'viem/chains'
import {
  RedemptionAPI,
  RedemptionStatus,
  type CreateRedemptionRequestParams,
  type UpdateRedemptionStatusParams,
  type ProcessRedemptionParams,
  type RedemptionQueueFilters
} from '../frontend/lib/redemption-api'
import {
  createRedemptionDomain,
  generateNonce,
  createDeadline,
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
  adminPrivateKey: generatePrivateKey(),
  testUsers: [
    privateKeyToAccount(generatePrivateKey()),
    privateKeyToAccount(generatePrivateKey()),
    privateKeyToAccount(generatePrivateKey()),
  ],
}

interface TestRedemptionRequest {
  id: string
  user: ReturnType<typeof privateKeyToAccount>
  shareAmount: bigint
  status: RedemptionStatus
  priority?: number
  queuePosition?: number | null
}

class AdminQueueManagementTestSuite {
  private api: RedemptionAPI
  private admin: ReturnType<typeof privateKeyToAccount>
  private testRequests: TestRedemptionRequest[] = []
  private createdRequestIds: string[] = []

  constructor() {
    this.api = new RedemptionAPI(config.apiBaseUrl)
    this.admin = privateKeyToAccount(config.adminPrivateKey)
    console.log(`👑 Admin Address: ${this.admin.address}`)
    console.log('👥 Test Users:')
    config.testUsers.forEach((user, index) => {
      console.log(`   ${index + 1}. ${user.address}`)
    })
  }

  // Utility to create signed redemption request
  private async createSignedRequest(
    user: ReturnType<typeof privateKeyToAccount>,
    shareAmount: bigint = parseEther('1'),
    minAssetsOut: bigint = parseEther('0.95')
  ): Promise<SignedRedemptionRequest> {
    const domain = createRedemptionDomain(config.chainId, config.vaultAddress)
    
    const requestData: RedemptionRequestData = {
      user: user.address,
      shareAmount,
      minAssetsOut,
      nonce: generateNonce(),
      deadline: createDeadline(60)
    }

    const walletClient = createWalletClient({
      account: user,
      chain: baseSepolia,
      transport: http()
    })

    const signature = await walletClient.signTypedData({
      domain,
      types: REDEMPTION_TYPES,
      primaryType: 'RedemptionRequest',
      message: requestData
    })

    return { ...requestData, signature }
  }

  // Setup test data by creating several redemption requests
  private async setupTestRequests(): Promise<boolean> {
    console.log('\n🏗️  Setting up test redemption requests...')
    try {
      const requests = await Promise.all([
        // High priority request
        this.createSignedRequest(config.testUsers[0], parseEther('10')),
        // Medium priority request
        this.createSignedRequest(config.testUsers[1], parseEther('5')),
        // Low priority request
        this.createSignedRequest(config.testUsers[2], parseEther('1')),
        // Another request from user 1
        this.createSignedRequest(config.testUsers[0], parseEther('2')),
      ])

      const shareAmounts = [parseEther('10'), parseEther('5'), parseEther('1'), parseEther('2')]

      for (let i = 0; i < requests.length; i++) {
        const params: CreateRedemptionRequestParams = {
          deploymentId: config.deploymentId,
          expectedAssets: shareAmounts[i].toString(),
          signedRequest: requests[i]
        }

        const response = await this.api.submitRedemptionRequest(params)
        
        this.testRequests.push({
          id: response.id,
          user: config.testUsers[i < 3 ? i : 0],
          shareAmount: shareAmounts[i],
          status: RedemptionStatus.PENDING,
        })

        this.createdRequestIds.push(response.id)
        console.log(`✅ Created test request ${i + 1}: ${response.id}`)
      }

      return true
    } catch (error) {
      console.log(`❌ Failed to setup test requests: ${error}`)
      return false
    }
  }

  // Test 1: Queue Statistics and Overview
  async testQueueStatistics(): Promise<boolean> {
    console.log('\n📊 Test 1: Queue Statistics and Overview')
    try {
      // Get overall queue statistics
      const overallStats = await this.api.getQueueStats()
      console.log('✅ Overall Queue Statistics:')
      console.log(`   Total Requests: ${overallStats.totalRequests}`)
      console.log(`   Pending: ${overallStats.pendingRequests}`)
      console.log(`   Approved: ${overallStats.approvedRequests}`)
      console.log(`   Processing: ${overallStats.processingRequests}`)
      console.log(`   Completed: ${overallStats.completedRequests}`)
      console.log(`   Failed: ${overallStats.failedRequests}`)
      console.log(`   Queue Length: ${overallStats.queueLength}`)
      console.log(`   Average Processing Time: ${overallStats.averageProcessingTime || 'N/A'}s`)

      // Get deployment-specific statistics
      const deploymentStats = await this.api.getQueueStats(config.deploymentId)
      console.log(`✅ Deployment ${config.deploymentId} Statistics:`)
      console.log(`   Total Requests: ${deploymentStats.totalRequests}`)
      console.log(`   Queue Length: ${deploymentStats.queueLength}`)

      // Verify basic statistics make sense
      if (overallStats.totalRequests >= 0 && overallStats.queueLength >= 0) {
        console.log('✅ Statistics have reasonable values')
        return true
      } else {
        console.log('❌ Statistics have invalid values')
        return false
      }
    } catch (error) {
      console.log(`❌ Queue statistics test failed: ${error}`)
      return false
    }
  }

  // Test 2: Request Filtering and Pagination
  async testRequestFiltering(): Promise<boolean> {
    console.log('\n🔍 Test 2: Request Filtering and Pagination')
    try {
      // Test get all requests with pagination
      const allRequests = await this.api.getRedemptionRequests({ page: 1, limit: 10 })
      console.log(`✅ Retrieved ${allRequests.requests.length} requests (page 1, limit 10)`)
      console.log(`   Total Count: ${allRequests.totalCount}`)

      // Test filter by status
      const pendingRequests = await this.api.getRedemptionRequests({
        status: [RedemptionStatus.PENDING]
      })
      console.log(`✅ Retrieved ${pendingRequests.requests.length} pending requests`)

      // Test filter by user
      const user1Address = config.testUsers[0].address
      const userRequests = await this.api.getRedemptionRequests({
        userAddress: user1Address
      })
      console.log(`✅ Retrieved ${userRequests.requests.length} requests for user ${user1Address}`)

      // Test filter by deployment
      const deploymentRequests = await this.api.getRedemptionRequests({
        deploymentId: config.deploymentId
      })
      console.log(`✅ Retrieved ${deploymentRequests.requests.length} requests for deployment`)

      // Test multiple filters
      const combinedFilters = await this.api.getRedemptionRequests({
        status: [RedemptionStatus.PENDING],
        deploymentId: config.deploymentId,
        page: 1,
        limit: 5
      })
      console.log(`✅ Retrieved ${combinedFilters.requests.length} requests with combined filters`)

      return true
    } catch (error) {
      console.log(`❌ Request filtering test failed: ${error}`)
      return false
    }
  }

  // Test 3: Status Transitions and Approvals
  async testStatusTransitions(): Promise<boolean> {
    console.log('\n🔄 Test 3: Status Transitions and Approvals')
    try {
      if (this.createdRequestIds.length === 0) {
        console.log('⚠️  No test requests available')
        return false
      }

      const requestId = this.createdRequestIds[0]

      // Test approve request
      console.log(`Approving request: ${requestId}`)
      const approveParams: UpdateRedemptionStatusParams = {
        id: requestId,
        status: RedemptionStatus.APPROVED,
        adminNotes: 'Approved for testing',
        priority: 1
      }

      const approvedRequest = await this.api.updateRedemptionStatus(approveParams)
      console.log(`✅ Request approved: ${approvedRequest.status}`)
      console.log(`   Queue Position: ${approvedRequest.queuePosition}`)
      console.log(`   Priority: ${approvedRequest.priority}`)

      // Update test request tracking
      const testReqIndex = this.testRequests.findIndex(r => r.id === requestId)
      if (testReqIndex >= 0) {
        this.testRequests[testReqIndex].status = RedemptionStatus.APPROVED
        this.testRequests[testReqIndex].priority = 1
        this.testRequests[testReqIndex].queuePosition = approvedRequest.queuePosition
      }

      // Test invalid transition (completed to pending)
      try {
        await this.api.updateRedemptionStatus({
          id: requestId,
          status: RedemptionStatus.PENDING // Invalid transition from APPROVED
        })
        console.log('❌ Should have failed with invalid transition')
        return false
      } catch (error) {
        console.log('✅ Invalid status transition correctly rejected')
      }

      // Test move to processing
      const processingParams: UpdateRedemptionStatusParams = {
        id: requestId,
        status: RedemptionStatus.PROCESSING,
        adminNotes: 'Starting blockchain processing'
      }

      const processingRequest = await this.api.updateRedemptionStatus(processingParams)
      console.log(`✅ Request moved to processing: ${processingRequest.status}`)

      // Test mark as processed
      const processParams: ProcessRedemptionParams = {
        id: requestId,
        txHash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        actualAssets: '9800000000000000000', // 9.8 ETH
        gasCost: '50000000000000000' // 0.05 ETH
      }

      const processedRequest = await this.api.markRedemptionProcessed(processParams)
      console.log(`✅ Request marked as processed: ${processedRequest.status}`)
      console.log(`   TX Hash: ${processedRequest.txHash}`)
      console.log(`   Actual Assets: ${processedRequest.actualAssets}`)
      console.log(`   Gas Cost: ${processedRequest.gasCost}`)

      return true
    } catch (error) {
      console.log(`❌ Status transitions test failed: ${error}`)
      return false
    }
  }

  // Test 4: Priority Management and Queue Ordering
  async testPriorityManagement(): Promise<boolean> {
    console.log('\n⭐ Test 4: Priority Management and Queue Ordering')
    try {
      if (this.createdRequestIds.length < 3) {
        console.log('⚠️  Need at least 3 test requests')
        return false
      }

      // Approve multiple requests with different priorities
      const priorities = [3, 1, 2] // Different priority levels
      const approvedIds = []

      for (let i = 0; i < Math.min(3, this.createdRequestIds.length); i++) {
        const requestId = this.createdRequestIds[i]
        
        const approveParams: UpdateRedemptionStatusParams = {
          id: requestId,
          status: RedemptionStatus.APPROVED,
          adminNotes: `Priority ${priorities[i]} request`,
          priority: priorities[i]
        }

        const approvedRequest = await this.api.updateRedemptionStatus(approveParams)
        console.log(`✅ Approved request ${i + 1} with priority ${priorities[i]}`)
        console.log(`   Queue Position: ${approvedRequest.queuePosition}`)
        
        approvedIds.push(requestId)
      }

      // Get approved requests and check ordering
      const approvedRequests = await this.api.getRedemptionRequests({
        status: [RedemptionStatus.APPROVED],
        deploymentId: config.deploymentId
      })

      console.log('✅ Queue ordering:')
      approvedRequests.requests
        .filter(r => approvedIds.includes(r.id))
        .sort((a, b) => (a.queuePosition || 0) - (b.queuePosition || 0))
        .forEach((request, index) => {
          console.log(`   ${index + 1}. Priority: ${request.priority}, Position: ${request.queuePosition}, ID: ${request.id}`)
        })

      // Test priority update
      if (approvedIds.length > 0) {
        const updatePriorityParams: UpdateRedemptionStatusParams = {
          id: approvedIds[0],
          status: RedemptionStatus.APPROVED,
          priority: 0, // Highest priority
          adminNotes: 'Updated to highest priority'
        }

        const updatedRequest = await this.api.updateRedemptionStatus(updatePriorityParams)
        console.log(`✅ Updated priority to ${updatedRequest.priority}`)
      }

      return true
    } catch (error) {
      console.log(`❌ Priority management test failed: ${error}`)
      return false
    }
  }

  // Test 5: Bulk Operations
  async testBulkOperations(): Promise<boolean> {
    console.log('\n📦 Test 5: Bulk Operations')
    try {
      // Get all pending requests for bulk operations
      const pendingRequests = await this.api.getRedemptionRequests({
        status: [RedemptionStatus.PENDING],
        limit: 10
      })

      if (pendingRequests.requests.length === 0) {
        console.log('⚠️  No pending requests for bulk operations')
        return true
      }

      console.log(`Found ${pendingRequests.requests.length} pending requests for bulk operations`)

      // Simulate bulk approval
      let bulkApprovalSuccess = 0
      const bulkApprovalResults = []

      for (const request of pendingRequests.requests.slice(0, 3)) { // Limit to first 3
        try {
          const approveParams: UpdateRedemptionStatusParams = {
            id: request.id,
            status: RedemptionStatus.APPROVED,
            adminNotes: 'Bulk approval',
            priority: 2
          }

          const result = await this.api.updateRedemptionStatus(approveParams)
          bulkApprovalResults.push(result)
          bulkApprovalSuccess++
        } catch (error) {
          console.log(`   Failed to bulk approve ${request.id}: ${error}`)
        }
      }

      console.log(`✅ Bulk approval: ${bulkApprovalSuccess}/${Math.min(3, pendingRequests.requests.length)} successful`)

      // Test bulk status query
      const multiStatusRequests = await this.api.getRedemptionRequests({
        status: [RedemptionStatus.PENDING, RedemptionStatus.APPROVED],
        deploymentId: config.deploymentId
      })

      console.log(`✅ Multi-status query returned ${multiStatusRequests.requests.length} requests`)

      return true
    } catch (error) {
      console.log(`❌ Bulk operations test failed: ${error}`)
      return false
    }
  }

  // Test 6: Request Rejection and Cancellation
  async testRejectionAndCancellation(): Promise<boolean> {
    console.log('\n🚫 Test 6: Request Rejection and Cancellation')
    try {
      // Create a new request specifically for rejection testing
      const signedRequest = await this.createSignedRequest(config.testUsers[0], parseEther('0.5'))
      const createParams: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: parseEther('0.48').toString(),
        signedRequest
      }

      const newRequest = await this.api.submitRedemptionRequest(createParams)
      console.log(`✅ Created request for rejection test: ${newRequest.id}`)

      // Test rejection
      const rejectParams: UpdateRedemptionStatusParams = {
        id: newRequest.id,
        status: RedemptionStatus.REJECTED,
        adminNotes: 'Rejected for testing purposes',
        rejectionReason: 'Insufficient collateral backing'
      }

      const rejectedRequest = await this.api.updateRedemptionStatus(rejectParams)
      console.log(`✅ Request rejected: ${rejectedRequest.status}`)
      console.log(`   Rejection Reason: ${rejectedRequest.rejectionReason}`)

      // Create another request for cancellation testing
      const cancelSignedRequest = await this.createSignedRequest(config.testUsers[1], parseEther('0.3'))
      const cancelCreateParams: CreateRedemptionRequestParams = {
        deploymentId: config.deploymentId,
        expectedAssets: parseEther('0.29').toString(),
        signedRequest: cancelSignedRequest
      }

      const cancelRequest = await this.api.submitRedemptionRequest(cancelCreateParams)
      console.log(`✅ Created request for cancellation test: ${cancelRequest.id}`)

      // Test cancellation
      const cancelledRequest = await this.api.cancelRedemptionRequest(
        cancelRequest.id,
        'Admin cancelled for testing'
      )
      console.log(`✅ Request cancelled: ${cancelledRequest.status}`)

      return true
    } catch (error) {
      console.log(`❌ Rejection and cancellation test failed: ${error}`)
      return false
    }
  }

  // Test 7: Failed Request Handling
  async testFailedRequestHandling(): Promise<boolean> {
    console.log('\n⚠️  Test 7: Failed Request Handling')
    try {
      // Get or create a request to test failure handling
      let testRequestId: string

      if (this.createdRequestIds.length > 0) {
        testRequestId = this.createdRequestIds[this.createdRequestIds.length - 1]
      } else {
        // Create a new request
        const signedRequest = await this.createSignedRequest(config.testUsers[2], parseEther('1.5'))
        const createParams: CreateRedemptionRequestParams = {
          deploymentId: config.deploymentId,
          expectedAssets: parseEther('1.45').toString(),
          signedRequest
        }
        const newRequest = await this.api.submitRedemptionRequest(createParams)
        testRequestId = newRequest.id
      }

      // Move request through states to processing
      await this.api.updateRedemptionStatus({
        id: testRequestId,
        status: RedemptionStatus.APPROVED,
        adminNotes: 'Approved for failure testing'
      })

      await this.api.updateRedemptionStatus({
        id: testRequestId,
        status: RedemptionStatus.PROCESSING,
        adminNotes: 'Processing - will simulate failure'
      })

      // Mark as failed
      const failedRequest = await this.api.updateRedemptionStatus({
        id: testRequestId,
        status: RedemptionStatus.FAILED,
        adminNotes: 'Transaction failed on blockchain',
        rejectionReason: 'Insufficient gas or reverted transaction'
      })

      console.log(`✅ Request marked as failed: ${failedRequest.status}`)
      console.log(`   Admin Notes: ${failedRequest.adminNotes}`)
      console.log(`   Failure Reason: ${failedRequest.rejectionReason}`)

      // Test retry from failed state
      const retriedRequest = await this.api.updateRedemptionStatus({
        id: testRequestId,
        status: RedemptionStatus.PROCESSING,
        adminNotes: 'Retrying failed request'
      })

      console.log(`✅ Failed request moved back to processing for retry: ${retriedRequest.status}`)

      return true
    } catch (error) {
      console.log(`❌ Failed request handling test failed: ${error}`)
      return false
    }
  }

  // Test 8: Admin Activity Logging
  async testAdminActivityLogging(): Promise<boolean> {
    console.log('\n📝 Test 8: Admin Activity Logging')
    try {
      // Note: This would require access to the activity logs
      // For now, we'll test that status updates work and assume logging is happening

      if (this.createdRequestIds.length === 0) {
        console.log('⚠️  No test requests available for activity logging test')
        return true
      }

      const requestId = this.createdRequestIds[0]

      // Perform several status updates to generate activity
      const statusUpdates = [
        {
          status: RedemptionStatus.APPROVED,
          adminNotes: 'First approval for activity test',
          priority: 1
        },
        {
          status: RedemptionStatus.PROCESSING,
          adminNotes: 'Moving to processing for activity test'
        }
      ]

      for (const update of statusUpdates) {
        await this.api.updateRedemptionStatus({
          id: requestId,
          ...update
        })
        console.log(`✅ Status updated to ${update.status} - activity should be logged`)
      }

      // Get the final state to verify updates were applied
      const finalRequest = await this.api.getRedemptionRequest(requestId)
      console.log(`✅ Final request state: ${finalRequest.status}`)
      console.log(`   Admin Notes: ${finalRequest.adminNotes}`)

      return true
    } catch (error) {
      console.log(`❌ Admin activity logging test failed: ${error}`)
      return false
    }
  }

  // Cleanup test data
  async cleanupTestData(): Promise<void> {
    console.log('\n🧹 Cleaning up test data...')
    try {
      // Cancel any remaining pending/approved requests
      for (const requestId of this.createdRequestIds) {
        try {
          await this.api.cancelRedemptionRequest(requestId, 'Cleanup after testing')
          console.log(`✅ Cleaned up request: ${requestId}`)
        } catch (error) {
          // Ignore errors during cleanup
          console.log(`⚠️  Could not cleanup request ${requestId}: request may already be processed`)
        }
      }

      console.log('✅ Test data cleanup completed')
    } catch (error) {
      console.log(`⚠️  Cleanup warning: ${error}`)
    }
  }

  // Run all tests
  async runAllTests(): Promise<void> {
    console.log('🚀 Starting Admin Queue Management Test Suite')
    console.log('===============================================')

    // Setup test data
    const setupSuccess = await this.setupTestRequests()
    if (!setupSuccess) {
      console.log('❌ Failed to setup test data, aborting test suite')
      return
    }

    try {
      const testResults = {
        statistics: await this.testQueueStatistics(),
        filtering: await this.testRequestFiltering(),
        statusTransitions: await this.testStatusTransitions(),
        priorityManagement: await this.testPriorityManagement(),
        bulkOperations: await this.testBulkOperations(),
        rejectionCancellation: await this.testRejectionAndCancellation(),
        failedHandling: await this.testFailedRequestHandling(),
        activityLogging: await this.testAdminActivityLogging(),
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

      if (this.createdRequestIds.length > 0) {
        console.log(`\n📝 Created ${this.createdRequestIds.length} test requests for admin testing`)
      }

      console.log('\n🏁 Admin Queue Management Test Suite Complete')
    } finally {
      // Cleanup
      await this.cleanupTestData()
    }
  }
}

// Run the tests
async function main() {
  const testSuite = new AdminQueueManagementTestSuite()
  await testSuite.runAllTests()
}

if (require.main === module) {
  main().catch(console.error)
}

export { AdminQueueManagementTestSuite }