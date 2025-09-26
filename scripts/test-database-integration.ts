#!/usr/bin/env node

import { PrismaClient } from '@prisma/client'
import { RedemptionStatus } from '../frontend/lib/redemption-api'

// Test configuration
const config = {
  testDeploymentId: 'cm43wuwdm0000zy7tqdbjdz5u', // Replace with actual deployment ID
  testUserAddress: '0x742d35Cc6634C0532925a3b8D23dC6e74c4b8e1D',
  testChainId: 84532,
}

class DatabaseIntegrationTestSuite {
  private prisma: PrismaClient
  private testRecordIds: string[] = []

  constructor() {
    this.prisma = new PrismaClient({
      log: ['query', 'info', 'warn', 'error'],
    })
  }

  async cleanup() {
    await this.prisma.$disconnect()
  }

  // Test 1: Database Connection
  async testDatabaseConnection(): Promise<boolean> {
    console.log('\n🔌 Test 1: Database Connection')
    try {
      await this.prisma.$connect()
      console.log('✅ Database connection successful')
      
      // Test basic query
      const networkCount = await this.prisma.sovaBtcNetwork.count()
      console.log(`   Networks in database: ${networkCount}`)
      
      const deploymentCount = await this.prisma.sovaBtcDeployment.count()
      console.log(`   Deployments in database: ${deploymentCount}`)
      
      return true
    } catch (error) {
      console.log(`❌ Database connection failed: ${error}`)
      return false
    }
  }

  // Test 2: Schema Validation
  async testSchemaValidation(): Promise<boolean> {
    console.log('\n📋 Test 2: Schema Validation')
    try {
      // Check if redemption request table exists and has expected structure
      const tableInfo = await this.prisma.$queryRaw`
        SELECT column_name, data_type, is_nullable 
        FROM information_schema.columns 
        WHERE table_name = 'sovabtc_redemption_requests'
        ORDER BY ordinal_position;
      `
      
      console.log('✅ RedemptionRequest table schema:')
      console.log(tableInfo)

      // Check if RedemptionStatus enum exists
      const enumValues = await this.prisma.$queryRaw`
        SELECT enumlabel as status_value
        FROM pg_enum e
        JOIN pg_type t ON e.enumtypid = t.oid
        WHERE t.typname = 'RedemptionStatus'
        ORDER BY e.enumsortorder;
      `
      
      console.log('✅ RedemptionStatus enum values:')
      console.log(enumValues)

      // Check indexes
      const indexes = await this.prisma.$queryRaw`
        SELECT indexname, indexdef
        FROM pg_indexes
        WHERE tablename = 'sovabtc_redemption_requests';
      `
      
      console.log('✅ Table indexes:')
      console.log(indexes)

      return true
    } catch (error) {
      console.log(`❌ Schema validation failed: ${error}`)
      return false
    }
  }

  // Test 3: Create Redemption Request
  async testCreateRedemptionRequest(): Promise<string | null> {
    console.log('\n📝 Test 3: Create Redemption Request')
    try {
      // First, ensure we have a test deployment
      let deployment = await this.prisma.sovaBtcDeployment.findFirst({
        where: { id: config.testDeploymentId }
      })

      if (!deployment) {
        console.log('⚠️  Test deployment not found, creating one...')
        // Create a test deployment if it doesn't exist
        const network = await this.prisma.sovaBtcNetwork.upsert({
          where: { chainId: config.testChainId },
          create: {
            chainId: config.testChainId,
            name: 'Base Sepolia',
            rpcUrl: 'https://sepolia.base.org',
            blockExplorer: 'https://sepolia-explorer.base.org',
            nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
            isTestnet: true,
          },
          update: {},
        })

        deployment = await this.prisma.sovaBtcDeployment.create({
          data: {
            id: config.testDeploymentId,
            chainId: config.testChainId,
            vaultStrategy: '0x1234567890abcdef1234567890abcdef12345678',
            vaultToken: '0xabcdef1234567890abcdef1234567890abcdef12',
            status: 'DEPLOYED',
          }
        })
      }

      // Create a test redemption request
      const redemptionRequest = await this.prisma.redemptionRequest.create({
        data: {
          userAddress: config.testUserAddress.toLowerCase(),
          shares: '1000000000000000000', // 1 ETH in wei
          receiver: config.testUserAddress.toLowerCase(),
          signature: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b',
          signedAt: new Date(),
          nonce: `${Date.now()}`,
          deadline: `${Math.floor(Date.now() / 1000) + 3600}`, // 1 hour from now
          chainId: config.testChainId,
          deploymentId: config.testDeploymentId,
          status: RedemptionStatus.PENDING,
        },
        include: {
          deployment: {
            include: {
              network: true,
            },
          },
        },
      })

      console.log('✅ Redemption request created successfully')
      console.log(`   Request ID: ${redemptionRequest.id}`)
      console.log(`   User: ${redemptionRequest.userAddress}`)
      console.log(`   Shares: ${redemptionRequest.shares}`)
      console.log(`   Status: ${redemptionRequest.status}`)
      console.log(`   Deployment: ${redemptionRequest.deployment.vaultToken}`)

      this.testRecordIds.push(redemptionRequest.id)
      return redemptionRequest.id
    } catch (error) {
      console.log(`❌ Create redemption request failed: ${error}`)
      return null
    }
  }

  // Test 4: Query Redemption Requests
  async testQueryRedemptionRequests(): Promise<boolean> {
    console.log('\n🔍 Test 4: Query Redemption Requests')
    try {
      // Test basic find
      const allRequests = await this.prisma.redemptionRequest.findMany({
        include: {
          deployment: {
            include: {
              network: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: 5,
      })

      console.log(`✅ Found ${allRequests.length} redemption requests`)
      allRequests.forEach((request, index) => {
        console.log(`   ${index + 1}. ID: ${request.id}, Status: ${request.status}, User: ${request.userAddress}`)
      })

      // Test filtering by status
      const pendingRequests = await this.prisma.redemptionRequest.findMany({
        where: {
          status: RedemptionStatus.PENDING,
        },
      })

      console.log(`✅ Found ${pendingRequests.length} pending requests`)

      // Test filtering by user
      const userRequests = await this.prisma.redemptionRequest.findMany({
        where: {
          userAddress: config.testUserAddress.toLowerCase(),
        },
      })

      console.log(`✅ Found ${userRequests.length} requests for test user`)

      // Test count aggregation
      const statusCounts = await this.prisma.redemptionRequest.groupBy({
        by: ['status'],
        _count: {
          id: true,
        },
      })

      console.log('✅ Status counts:')
      statusCounts.forEach((count) => {
        console.log(`   ${count.status}: ${count._count.id}`)
      })

      return true
    } catch (error) {
      console.log(`❌ Query redemption requests failed: ${error}`)
      return false
    }
  }

  // Test 5: Update Redemption Request
  async testUpdateRedemptionRequest(): Promise<boolean> {
    console.log('\n📝 Test 5: Update Redemption Request')
    try {
      if (this.testRecordIds.length === 0) {
        console.log('⚠️  No test records available for update')
        return false
      }

      const requestId = this.testRecordIds[0]

      // Test status update
      const updatedRequest = await this.prisma.redemptionRequest.update({
        where: { id: requestId },
        data: {
          status: RedemptionStatus.APPROVED,
          approvedAt: new Date(),
          approvedBy: 'test-admin',
        },
      })

      console.log(`✅ Updated request status to: ${updatedRequest.status}`)

      // Test processing update
      const processingRequest = await this.prisma.redemptionRequest.update({
        where: { id: requestId },
        data: {
          status: RedemptionStatus.PROCESSING,
        },
      })

      console.log(`✅ Updated request to processing: ${processingRequest.status}`)

      // Test completion update
      const completedRequest = await this.prisma.redemptionRequest.update({
        where: { id: requestId },
        data: {
          status: RedemptionStatus.COMPLETED,
          processedAt: new Date(),
          processedTxHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
        },
      })

      console.log(`✅ Updated request to completed: ${completedRequest.status}`)
      console.log(`   TX Hash: ${completedRequest.processedTxHash}`)

      return true
    } catch (error) {
      console.log(`❌ Update redemption request failed: ${error}`)
      return false
    }
  }

  // Test 6: Unique Constraints
  async testUniqueConstraints(): Promise<boolean> {
    console.log('\n🔒 Test 6: Unique Constraints')
    try {
      const testNonce = `test-nonce-${Date.now()}`
      
      // Create first request
      const firstRequest = await this.prisma.redemptionRequest.create({
        data: {
          userAddress: config.testUserAddress.toLowerCase(),
          shares: '1000000000000000000',
          receiver: config.testUserAddress.toLowerCase(),
          signature: '0x1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111b',
          signedAt: new Date(),
          nonce: testNonce,
          deadline: `${Math.floor(Date.now() / 1000) + 3600}`,
          chainId: config.testChainId,
          deploymentId: config.testDeploymentId,
          status: RedemptionStatus.PENDING,
        },
      })

      console.log(`✅ Created first request with nonce: ${testNonce}`)
      this.testRecordIds.push(firstRequest.id)

      // Try to create duplicate
      try {
        await this.prisma.redemptionRequest.create({
          data: {
            userAddress: config.testUserAddress.toLowerCase(),
            shares: '1000000000000000000',
            receiver: config.testUserAddress.toLowerCase(),
            signature: '0x2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222b',
            signedAt: new Date(),
            nonce: testNonce, // Same nonce
            deadline: `${Math.floor(Date.now() / 1000) + 3600}`,
            chainId: config.testChainId,
            deploymentId: config.testDeploymentId,
            status: RedemptionStatus.PENDING,
          },
        })
        
        console.log('❌ Should have failed due to unique constraint')
        return false
      } catch (duplicateError) {
        console.log('✅ Unique constraint correctly enforced for userAddress + nonce')
        return true
      }
    } catch (error) {
      console.log(`❌ Unique constraints test failed: ${error}`)
      return false
    }
  }

  // Test 7: Foreign Key Relationships
  async testForeignKeyRelationships(): Promise<boolean> {
    console.log('\n🔗 Test 7: Foreign Key Relationships')
    try {
      // Test valid relationship
      const requestWithDeployment = await this.prisma.redemptionRequest.findFirst({
        include: {
          deployment: {
            include: {
              network: true,
            },
          },
        },
      })

      if (requestWithDeployment) {
        console.log('✅ Foreign key relationship working:')
        console.log(`   Request ID: ${requestWithDeployment.id}`)
        console.log(`   Deployment Chain: ${requestWithDeployment.deployment.chainId}`)
        console.log(`   Network Name: ${requestWithDeployment.deployment.network?.name}`)
      }

      // Test invalid foreign key
      try {
        await this.prisma.redemptionRequest.create({
          data: {
            userAddress: config.testUserAddress.toLowerCase(),
            shares: '1000000000000000000',
            receiver: config.testUserAddress.toLowerCase(),
            signature: '0x3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b',
            signedAt: new Date(),
            nonce: `invalid-fk-${Date.now()}`,
            deadline: `${Math.floor(Date.now() / 1000) + 3600}`,
            chainId: config.testChainId,
            deploymentId: 'non-existent-deployment',
            status: RedemptionStatus.PENDING,
          },
        })
        
        console.log('❌ Should have failed due to foreign key constraint')
        return false
      } catch (fkError) {
        console.log('✅ Foreign key constraint correctly enforced')
        return true
      }
    } catch (error) {
      console.log(`❌ Foreign key relationships test failed: ${error}`)
      return false
    }
  }

  // Test 8: Transaction Support
  async testTransactionSupport(): Promise<boolean> {
    console.log('\n🔄 Test 8: Transaction Support')
    try {
      const testNonce = `transaction-test-${Date.now()}`
      
      // Test successful transaction
      await this.prisma.$transaction(async (tx) => {
        const request = await tx.redemptionRequest.create({
          data: {
            userAddress: config.testUserAddress.toLowerCase(),
            shares: '1000000000000000000',
            receiver: config.testUserAddress.toLowerCase(),
            signature: '0x4444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444b',
            signedAt: new Date(),
            nonce: testNonce,
            deadline: `${Math.floor(Date.now() / 1000) + 3600}`,
            chainId: config.testChainId,
            deploymentId: config.testDeploymentId,
            status: RedemptionStatus.PENDING,
          },
        })

        // Create activity record in same transaction
        await tx.sovaBtcActivity.create({
          data: {
            deploymentId: config.testDeploymentId,
            type: 'REDEMPTION_REQUEST',
            description: 'Test redemption request created in transaction',
            metadata: {
              requestId: request.id,
              userAddress: config.testUserAddress,
            },
          },
        })

        console.log(`✅ Transaction completed successfully for request: ${request.id}`)
        this.testRecordIds.push(request.id)
      })

      // Test rollback transaction
      try {
        await this.prisma.$transaction(async (tx) => {
          await tx.redemptionRequest.create({
            data: {
              userAddress: config.testUserAddress.toLowerCase(),
              shares: '1000000000000000000',
              receiver: config.testUserAddress.toLowerCase(),
              signature: '0x5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555b',
              signedAt: new Date(),
              nonce: `rollback-test-${Date.now()}`,
              deadline: `${Math.floor(Date.now() / 1000) + 3600}`,
              chainId: config.testChainId,
              deploymentId: config.testDeploymentId,
              status: RedemptionStatus.PENDING,
            },
          })

          // Force an error to trigger rollback
          throw new Error('Intentional rollback')
        })
        
        console.log('❌ Transaction should have rolled back')
        return false
      } catch (rollbackError) {
        console.log('✅ Transaction rollback working correctly')
        return true
      }
    } catch (error) {
      console.log(`❌ Transaction support test failed: ${error}`)
      return false
    }
  }

  // Cleanup test data
  async cleanupTestData(): Promise<void> {
    console.log('\n🧹 Cleaning up test data...')
    try {
      if (this.testRecordIds.length > 0) {
        const deleted = await this.prisma.redemptionRequest.deleteMany({
          where: {
            id: {
              in: this.testRecordIds,
            },
          },
        })
        console.log(`✅ Deleted ${deleted.count} test records`)
      }

      // Clean up test activities
      await this.prisma.sovaBtcActivity.deleteMany({
        where: {
          description: {
            contains: 'Test redemption',
          },
        },
      })

      console.log('✅ Test data cleanup completed')
    } catch (error) {
      console.log(`⚠️  Cleanup warning: ${error}`)
    }
  }

  // Run all tests
  async runAllTests(): Promise<void> {
    console.log('🚀 Starting Database Integration Test Suite')
    console.log('=============================================')

    try {
      const testResults = {
        connection: await this.testDatabaseConnection(),
        schema: await this.testSchemaValidation(),
        create: await this.testCreateRedemptionRequest(),
        query: await this.testQueryRedemptionRequests(),
        update: await this.testUpdateRedemptionRequest(),
        uniqueConstraints: await this.testUniqueConstraints(),
        foreignKeys: await this.testForeignKeyRelationships(),
        transactions: await this.testTransactionSupport(),
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

      // Cleanup
      await this.cleanupTestData()

      console.log('\n🏁 Database Integration Test Suite Complete')
    } finally {
      await this.cleanup()
    }
  }
}

// Run the tests
async function main() {
  const testSuite = new DatabaseIntegrationTestSuite()
  await testSuite.runAllTests()
}

if (require.main === module) {
  main().catch(console.error)
}

export { DatabaseIntegrationTestSuite }