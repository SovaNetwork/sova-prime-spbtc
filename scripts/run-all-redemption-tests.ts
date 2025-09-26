#!/usr/bin/env node

import { DatabaseIntegrationTestSuite } from './test-database-integration'
import { EIP712SignatureTestSuite } from './test-eip712-signatures'
import { RedemptionAPITestSuite } from './test-redemption-api-comprehensive'
import { AdminQueueManagementTestSuite } from './test-admin-queue-management'
import { E2ERedemptionFlowTestSuite } from './test-e2e-redemption-flow'

interface TestSuiteResult {
  name: string
  passed: boolean
  duration: number
  error?: string
}

class MasterTestRunner {
  private results: TestSuiteResult[] = []
  private startTime: number = 0

  constructor() {
    console.log('🧪 Master Redemption System Test Runner')
    console.log('=====================================')
    console.log('This will run comprehensive tests of the entire redemption system')
    console.log('')
  }

  private async runTestSuite(
    name: string,
    testSuite: any,
    methodName: string = 'runAllTests'
  ): Promise<boolean> {
    console.log(`\n🔄 Starting ${name}...`)
    console.log('='.repeat(50))
    
    const suiteStartTime = Date.now()
    let passed = false
    let error: string | undefined

    try {
      if (typeof testSuite[methodName] === 'function') {
        await testSuite[methodName]()
        passed = true
      } else {
        throw new Error(`Method ${methodName} not found on test suite`)
      }
    } catch (err) {
      passed = false
      error = err instanceof Error ? err.message : String(err)
      console.log(`❌ ${name} failed: ${error}`)
    }

    const duration = Date.now() - suiteStartTime
    this.results.push({ name, passed, duration, error })

    const status = passed ? '✅ PASSED' : '❌ FAILED'
    console.log(`\n${status} ${name} (${duration}ms)`)
    console.log('='.repeat(50))

    return passed
  }

  async runAllTests(): Promise<void> {
    this.startTime = Date.now()

    console.log('🚨 IMPORTANT NOTICE:')
    console.log('Before running these tests, ensure:')
    console.log('1. Frontend server is running on http://localhost:3000')
    console.log('2. Database is accessible and has correct schema')
    console.log('3. You have reviewed the schema-mismatch-analysis.md')
    console.log('')

    // Prompt user to continue
    console.log('Press Ctrl+C to abort, or wait 5 seconds to continue...')
    await new Promise(resolve => setTimeout(resolve, 5000))

    // Test Suite 1: EIP-712 Signature Verification (no dependencies)
    console.log('\n📝 Phase 1: Cryptographic Foundation Tests')
    await this.runTestSuite(
      'EIP-712 Signature Tests',
      new EIP712SignatureTestSuite(),
      'runAllTests'
    )

    // Test Suite 2: Database Integration (requires DB)
    console.log('\n🗄️  Phase 2: Database Integration Tests')
    await this.runTestSuite(
      'Database Integration Tests',
      new DatabaseIntegrationTestSuite(),
      'runAllTests'
    )

    // Test Suite 3: API Endpoint Tests (requires API server + DB)
    console.log('\n🌐 Phase 3: API Endpoint Tests')
    await this.runTestSuite(
      'API Endpoint Tests',
      new RedemptionAPITestSuite(),
      'runAllTests'
    )

    // Test Suite 4: Admin Queue Management (requires API + DB)
    console.log('\n👑 Phase 4: Admin Queue Management Tests')
    await this.runTestSuite(
      'Admin Queue Management Tests',
      new AdminQueueManagementTestSuite(),
      'runAllTests'
    )

    // Test Suite 5: End-to-End Flow Tests (requires everything)
    console.log('\n🎭 Phase 5: End-to-End Integration Tests')
    await this.runTestSuite(
      'E2E Redemption Flow Tests',
      new E2ERedemptionFlowTestSuite(),
      'runAllTests'
    )

    // Generate final report
    await this.generateFinalReport()
  }

  private async generateFinalReport(): Promise<void> {
    const totalDuration = Date.now() - this.startTime
    const passedTests = this.results.filter(r => r.passed).length
    const totalTests = this.results.length

    console.log('\n🎯 FINAL TEST REPORT')
    console.log('===================')
    console.log(`📊 Overall Results: ${passedTests}/${totalTests} test suites passed`)
    console.log(`⏱️  Total Runtime: ${(totalDuration / 1000).toFixed(2)} seconds`)
    console.log('')

    console.log('📋 Detailed Results:')
    this.results.forEach(result => {
      const status = result.passed ? '✅' : '❌'
      const duration = `${result.duration}ms`
      console.log(`${status} ${result.name.padEnd(35)} ${duration.padStart(8)}`)
      if (result.error) {
        console.log(`   Error: ${result.error}`)
      }
    })

    console.log('')

    // Production readiness assessment
    if (passedTests === totalTests) {
      console.log('🎉 PRODUCTION READY')
      console.log('===================')
      console.log('✅ All test suites passed successfully')
      console.log('✅ Redemption system is ready for production deployment')
      console.log('✅ All critical flows have been verified')
      console.log('')
      console.log('📋 Pre-deployment Checklist:')
      console.log('- [ ] Review all test outputs for warnings')
      console.log('- [ ] Ensure production environment matches test configuration')
      console.log('- [ ] Set up monitoring for redemption queue and processing')
      console.log('- [ ] Configure proper access controls for admin functions')
      console.log('- [ ] Verify gas optimization settings for blockchain interactions')
    } else if (passedTests >= totalTests * 0.8) {
      console.log('⚠️  MOSTLY READY - MINOR ISSUES')
      console.log('===============================')
      console.log(`✅ ${passedTests}/${totalTests} test suites passed`)
      console.log('⚠️  Some non-critical issues found')
      console.log('📝 Action Required:')
      console.log('- Review failed test suites and determine if issues are critical')
      console.log('- Fix any schema mismatches or API errors')
      console.log('- Re-run tests after fixes')
    } else if (passedTests >= totalTests * 0.5) {
      console.log('❌ NOT READY - SIGNIFICANT ISSUES')
      console.log('=================================')
      console.log(`❌ ${totalTests - passedTests}/${totalTests} test suites failed`)
      console.log('🚨 Critical issues found that prevent production deployment')
      console.log('📝 Action Required:')
      console.log('- Address schema mismatches (see schema-mismatch-analysis.md)')
      console.log('- Fix database connectivity and API endpoint issues')
      console.log('- Resolve EIP-712 signature verification problems')
      console.log('- Re-run all tests after fixes')
    } else {
      console.log('🚨 CRITICAL FAILURES - SYSTEM NOT FUNCTIONAL')
      console.log('============================================')
      console.log(`❌ ${totalTests - passedTests}/${totalTests} test suites failed`)
      console.log('💥 System has fundamental issues preventing basic functionality')
      console.log('📝 Immediate Action Required:')
      console.log('- Check if all services are running (frontend, database)')
      console.log('- Review schema-mismatch-analysis.md for critical fixes needed')
      console.log('- Verify network connectivity and environment configuration')
      console.log('- Consider rebuilding system components from scratch')
    }

    console.log('')
    console.log('📚 Additional Resources:')
    console.log('- Schema fixes: ./scripts/schema-mismatch-analysis.md')
    console.log('- Individual test scripts: ./scripts/test-*.ts')
    console.log('- API documentation: Check frontend/lib/redemption-api.ts')
    console.log('- EIP-712 implementation: Check frontend/lib/eip712.ts')

    console.log('\n🏁 Master Test Runner Complete')
  }

  // Utility method to run individual test categories
  static async runCategory(category: string): Promise<void> {
    const runner = new MasterTestRunner()
    
    switch (category.toLowerCase()) {
      case 'crypto':
      case 'eip712':
        await runner.runTestSuite(
          'EIP-712 Signature Tests',
          new EIP712SignatureTestSuite(),
          'runAllTests'
        )
        break
      
      case 'database':
      case 'db':
        await runner.runTestSuite(
          'Database Integration Tests',
          new DatabaseIntegrationTestSuite(),
          'runAllTests'
        )
        break
      
      case 'api':
        await runner.runTestSuite(
          'API Endpoint Tests',
          new RedemptionAPITestSuite(),
          'runAllTests'
        )
        break
      
      case 'admin':
        await runner.runTestSuite(
          'Admin Queue Management Tests',
          new AdminQueueManagementTestSuite(),
          'runAllTests'
        )
        break
      
      case 'e2e':
      case 'integration':
        await runner.runTestSuite(
          'E2E Redemption Flow Tests',
          new E2ERedemptionFlowTestSuite(),
          'runAllTests'
        )
        break
      
      default:
        console.log('❌ Unknown test category. Available categories:')
        console.log('- crypto/eip712: EIP-712 signature tests')
        console.log('- database/db: Database integration tests')
        console.log('- api: API endpoint tests')
        console.log('- admin: Admin queue management tests')
        console.log('- e2e/integration: End-to-end flow tests')
        break
    }

    await runner.generateFinalReport()
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2)
  
  if (args.length === 0) {
    // Run all tests
    const runner = new MasterTestRunner()
    await runner.runAllTests()
  } else if (args[0] === '--category' && args[1]) {
    // Run specific category
    await MasterTestRunner.runCategory(args[1])
  } else if (args[0] === '--help' || args[0] === '-h') {
    console.log('🧪 Master Redemption System Test Runner')
    console.log('')
    console.log('Usage:')
    console.log('  npm run test:redemption              # Run all test suites')
    console.log('  npm run test:redemption -- --category crypto   # Run EIP-712 tests only')
    console.log('  npm run test:redemption -- --category database # Run database tests only')
    console.log('  npm run test:redemption -- --category api      # Run API tests only')
    console.log('  npm run test:redemption -- --category admin    # Run admin tests only')
    console.log('  npm run test:redemption -- --category e2e      # Run E2E tests only')
    console.log('')
    console.log('Categories:')
    console.log('  crypto/eip712     - EIP-712 signature verification tests')
    console.log('  database/db       - Database integration and schema tests')
    console.log('  api               - API endpoint functionality tests')
    console.log('  admin             - Admin queue management tests')
    console.log('  e2e/integration   - End-to-end redemption flow tests')
    console.log('')
    console.log('Prerequisites:')
    console.log('- Frontend server running on http://localhost:3000')
    console.log('- Database accessible with correct schema')
    console.log('- Environment variables properly configured')
  } else {
    console.log('❌ Invalid arguments. Use --help for usage information.')
  }
}

if (require.main === module) {
  main().catch(console.error)
}

export { MasterTestRunner }