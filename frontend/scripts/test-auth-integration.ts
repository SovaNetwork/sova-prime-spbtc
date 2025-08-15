#!/usr/bin/env tsx
/**
 * Authentication & Rate Limiting Integration Test
 * 
 * Tests the complete authentication and rate limiting system working together
 * Validates that protected endpoints properly enforce both auth and rate limits
 * 
 * Usage: npx tsx scripts/test-auth-integration.ts
 */

import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

// Test configuration
const API_URL = process.env.API_URL || 'http://localhost:3000/api';

// Color output helpers
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m'
};

function log(message: string, color: keyof typeof colors = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// Test scenarios
interface TestScenario {
  name: string;
  description: string;
  run: () => Promise<boolean>;
}

const scenarios: TestScenario[] = [
  {
    name: 'Unauthenticated Rate Limiting',
    description: 'Verify rate limits apply to unauthenticated requests',
    run: async () => {
      log('  Testing public endpoint rate limiting...', 'gray');
      
      // Hit metrics endpoint 101 times (limit is 100/min)
      for (let i = 1; i <= 101; i++) {
        const response = await fetch(`${API_URL}/metrics/1`);
        
        if (i === 101 && response.status === 429) {
          log('  ✓ Rate limit correctly enforced at 101st request', 'green');
          
          // Check headers
          const limit = response.headers.get('X-RateLimit-Limit');
          const remaining = response.headers.get('X-RateLimit-Remaining');
          const reset = response.headers.get('X-RateLimit-Reset');
          
          if (limit && remaining && reset) {
            log('  ✓ Rate limit headers present', 'green');
            return true;
          } else {
            log('  ✗ Missing rate limit headers', 'red');
            return false;
          }
        } else if (i === 101 && response.status !== 429) {
          log(`  ✗ Rate limit not enforced (status: ${response.status})`, 'red');
          return false;
        }
      }
      
      return false;
    }
  },
  
  {
    name: 'Authenticated User Rate Limiting',
    description: 'Verify authenticated users have appropriate rate limits',
    run: async () => {
      log('  Creating test admin user...', 'gray');
      
      // Create test user
      const email = `ratelimit${Date.now()}@test.com`;
      const password = 'TestPassword123!';
      const passwordHash = await bcrypt.hash(password, 12);
      
      await prisma.adminUser.create({
        data: { email, passwordHash, role: 'ADMIN', isActive: true }
      });
      
      // Login to get token
      const loginResponse = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      if (!loginResponse.ok) {
        log('  ✗ Failed to login test user', 'red');
        return false;
      }
      
      const { accessToken } = await loginResponse.json();
      log('  ✓ Test user logged in', 'green');
      
      // Hit admin endpoint 51 times (limit is 50/min)
      for (let i = 1; i <= 51; i++) {
        const response = await fetch(`${API_URL}/deployments`, {
          headers: { 'Authorization': `Bearer ${accessToken}` }
        });
        
        if (i === 51 && response.status === 429) {
          log('  ✓ Admin rate limit correctly enforced at 51st request', 'green');
          
          // Cleanup
          await prisma.adminSession.deleteMany({ where: { user: { email } } });
          await prisma.adminUser.delete({ where: { email } });
          
          return true;
        } else if (i === 51 && response.status !== 429) {
          log(`  ✗ Admin rate limit not enforced (status: ${response.status})`, 'red');
          
          // Cleanup
          await prisma.adminSession.deleteMany({ where: { user: { email } } });
          await prisma.adminUser.delete({ where: { email } });
          
          return false;
        }
      }
      
      return false;
    }
  },
  
  {
    name: 'SUPER_ADMIN Rate Limit Bypass',
    description: 'Verify SUPER_ADMIN users bypass rate limits',
    run: async () => {
      log('  Creating SUPER_ADMIN user...', 'gray');
      
      // Create super admin
      const email = `superadmin${Date.now()}@test.com`;
      const password = 'SuperAdmin123!';
      const passwordHash = await bcrypt.hash(password, 12);
      
      await prisma.adminUser.create({
        data: { email, passwordHash, role: 'SUPER_ADMIN', isActive: true }
      });
      
      // Login
      const loginResponse = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      if (!loginResponse.ok) {
        log('  ✗ Failed to login SUPER_ADMIN', 'red');
        return false;
      }
      
      const { accessToken } = await loginResponse.json();
      log('  ✓ SUPER_ADMIN logged in', 'green');
      
      // Hit endpoint 100 times (should not be rate limited)
      let rateLimited = false;
      for (let i = 1; i <= 100; i++) {
        const response = await fetch(`${API_URL}/deployments`, {
          headers: { 'Authorization': `Bearer ${accessToken}` }
        });
        
        if (response.status === 429) {
          log(`  ✗ SUPER_ADMIN was rate limited at request ${i}`, 'red');
          rateLimited = true;
          break;
        }
      }
      
      // Cleanup
      await prisma.adminSession.deleteMany({ where: { user: { email } } });
      await prisma.adminUser.delete({ where: { email } });
      
      if (!rateLimited) {
        log('  ✓ SUPER_ADMIN successfully bypassed rate limits', 'green');
        return true;
      }
      
      return false;
    }
  },
  
  {
    name: 'Brute Force with Auth Protection',
    description: 'Verify brute force protection works with authentication',
    run: async () => {
      log('  Testing brute force protection...', 'gray');
      
      const email = 'bruteforce@test.com';
      let blocked = false;
      
      // Try 6 failed login attempts
      for (let i = 1; i <= 6; i++) {
        const response = await fetch(`${API_URL}/auth/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password: 'WrongPassword!' })
        });
        
        if (response.status === 429) {
          log(`  ✓ Blocked after ${i} failed attempts`, 'green');
          blocked = true;
          
          // Check for block duration header
          const blockedUntil = response.headers.get('X-RateLimit-Blocked-Until');
          if (blockedUntil) {
            const blockTime = new Date(blockedUntil);
            const now = new Date();
            const blockDuration = Math.round((blockTime.getTime() - now.getTime()) / 1000 / 60);
            log(`  ✓ Block duration: ~${blockDuration} minutes`, 'green');
            return true;
          } else {
            log('  ✗ Missing block duration header', 'red');
            return false;
          }
        }
      }
      
      if (!blocked) {
        log('  ✗ Not blocked after 6 failed attempts', 'red');
        return false;
      }
      
      return true;
    }
  },
  
  {
    name: 'Protected Endpoint Without Auth',
    description: 'Verify protected endpoints reject unauthenticated requests',
    run: async () => {
      log('  Testing protected endpoint access...', 'gray');
      
      // Try to access admin endpoint without auth
      const response = await fetch(`${API_URL}/admin/users`);
      
      if (response.status === 401) {
        log('  ✓ Correctly rejected with 401 Unauthorized', 'green');
        
        const data = await response.json();
        if (data.error && data.error.includes('Authentication required')) {
          log('  ✓ Proper error message returned', 'green');
          return true;
        } else {
          log('  ✗ Missing or incorrect error message', 'red');
          return false;
        }
      } else {
        log(`  ✗ Expected 401, got ${response.status}`, 'red');
        return false;
      }
    }
  },
  
  {
    name: 'Role-Based Access with Rate Limiting',
    description: 'Verify role restrictions work alongside rate limiting',
    run: async () => {
      log('  Creating OPERATOR user...', 'gray');
      
      // Create operator user
      const email = `operator${Date.now()}@test.com`;
      const password = 'Operator123!';
      const passwordHash = await bcrypt.hash(password, 12);
      
      await prisma.adminUser.create({
        data: { email, passwordHash, role: 'OPERATOR', isActive: true }
      });
      
      // Login
      const loginResponse = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      if (!loginResponse.ok) {
        log('  ✗ Failed to login OPERATOR', 'red');
        return false;
      }
      
      const { accessToken } = await loginResponse.json();
      log('  ✓ OPERATOR logged in', 'green');
      
      // Try to access SUPER_ADMIN only endpoint
      const response = await fetch(`${API_URL}/admin/users`, {
        headers: { 'Authorization': `Bearer ${accessToken}` }
      });
      
      // Cleanup
      await prisma.adminSession.deleteMany({ where: { user: { email } } });
      await prisma.adminUser.delete({ where: { email } });
      
      if (response.status === 403) {
        log('  ✓ OPERATOR correctly denied access with 403 Forbidden', 'green');
        
        // Verify rate limit headers still present
        const limit = response.headers.get('X-RateLimit-Limit');
        if (limit) {
          log('  ✓ Rate limit headers present even on forbidden request', 'green');
          return true;
        } else {
          log('  ✗ Missing rate limit headers on forbidden request', 'red');
          return false;
        }
      } else {
        log(`  ✗ Expected 403, got ${response.status}`, 'red');
        return false;
      }
    }
  },
  
  {
    name: 'Token Expiration Handling',
    description: 'Verify expired tokens are properly rejected',
    run: async () => {
      log('  Testing with invalid/expired token...', 'gray');
      
      // Use an obviously invalid token
      const response = await fetch(`${API_URL}/auth/me`, {
        headers: { 'Authorization': 'Bearer invalid.token.here' }
      });
      
      if (response.status === 401) {
        log('  ✓ Invalid token correctly rejected with 401', 'green');
        
        const data = await response.json();
        if (data.error && data.error.includes('Invalid token')) {
          log('  ✓ Proper error message for invalid token', 'green');
          return true;
        } else {
          log('  ✗ Missing or incorrect error message', 'red');
          return false;
        }
      } else {
        log(`  ✗ Expected 401, got ${response.status}`, 'red');
        return false;
      }
    }
  },
  
  {
    name: 'Concurrent Session Management',
    description: 'Verify multiple sessions work correctly',
    run: async () => {
      log('  Creating test user for sessions...', 'gray');
      
      // Create user
      const email = `sessions${Date.now()}@test.com`;
      const password = 'Sessions123!';
      const passwordHash = await bcrypt.hash(password, 12);
      
      await prisma.adminUser.create({
        data: { email, passwordHash, role: 'ADMIN', isActive: true }
      });
      
      // Create two sessions
      const session1 = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      const session2 = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      if (!session1.ok || !session2.ok) {
        log('  ✗ Failed to create sessions', 'red');
        return false;
      }
      
      const token1 = (await session1.json()).accessToken;
      const token2 = (await session2.json()).accessToken;
      
      // Verify both tokens work
      const check1 = await fetch(`${API_URL}/auth/me`, {
        headers: { 'Authorization': `Bearer ${token1}` }
      });
      
      const check2 = await fetch(`${API_URL}/auth/me`, {
        headers: { 'Authorization': `Bearer ${token2}` }
      });
      
      // Logout from session 1
      await fetch(`${API_URL}/auth/logout`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token1}` }
      });
      
      // Verify session 1 is invalid
      const check1After = await fetch(`${API_URL}/auth/me`, {
        headers: { 'Authorization': `Bearer ${token1}` }
      });
      
      // Verify session 2 still works
      const check2After = await fetch(`${API_URL}/auth/me`, {
        headers: { 'Authorization': `Bearer ${token2}` }
      });
      
      // Cleanup
      await prisma.adminSession.deleteMany({ where: { user: { email } } });
      await prisma.adminUser.delete({ where: { email } });
      
      if (check1.ok && check2.ok && !check1After.ok && check2After.ok) {
        log('  ✓ Multiple sessions managed correctly', 'green');
        log('  ✓ Logout affects only the specific session', 'green');
        return true;
      } else {
        log('  ✗ Session management issue detected', 'red');
        return false;
      }
    }
  },
  
  {
    name: 'API Write Operation Rate Limiting',
    description: 'Verify write operations have stricter rate limits',
    run: async () => {
      log('  Testing write operation rate limits...', 'gray');
      
      // Create admin user for testing
      const email = `writer${Date.now()}@test.com`;
      const password = 'Writer123!';
      const passwordHash = await bcrypt.hash(password, 12);
      
      await prisma.adminUser.create({
        data: { email, passwordHash, role: 'ADMIN', isActive: true }
      });
      
      // Login
      const loginResponse = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      if (!loginResponse.ok) {
        log('  ✗ Failed to login test user', 'red');
        return false;
      }
      
      const { accessToken } = await loginResponse.json();
      
      // Try 21 write operations (limit is 20/min)
      let rateLimited = false;
      for (let i = 1; i <= 21; i++) {
        const response = await fetch(`${API_URL}/collaterals`, {
          method: 'POST',
          headers: { 
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            deploymentId: 'test',
            address: '0x' + '0'.repeat(40),
            symbol: 'TEST',
            decimals: 18
          })
        });
        
        if (response.status === 429) {
          log(`  ✓ Write operations rate limited at request ${i}`, 'green');
          rateLimited = true;
          break;
        }
      }
      
      // Cleanup
      await prisma.adminSession.deleteMany({ where: { user: { email } } });
      await prisma.adminUser.delete({ where: { email } });
      
      return rateLimited;
    }
  }
];

// Main test runner
async function runIntegrationTests() {
  log('\n🔄 Authentication & Rate Limiting Integration Tests', 'blue');
  log('=' .repeat(60), 'blue');
  
  let passed = 0;
  let failed = 0;
  
  for (const scenario of scenarios) {
    log(`\n📋 ${scenario.name}`, 'cyan');
    log(`   ${scenario.description}`, 'gray');
    
    try {
      const result = await scenario.run();
      
      if (result) {
        passed++;
        log(`   ✅ PASSED`, 'green');
      } else {
        failed++;
        log(`   ❌ FAILED`, 'red');
      }
    } catch (error) {
      failed++;
      log(`   ❌ ERROR: ${error}`, 'red');
    }
    
    // Small delay between tests to avoid contamination
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  // Summary
  log('\n' + '=' .repeat(60), 'blue');
  log('📊 Integration Test Results', 'blue');
  log('=' .repeat(60), 'blue');
  log(`Total Scenarios: ${scenarios.length}`, 'cyan');
  log(`Passed: ${passed}`, 'green');
  log(`Failed: ${failed}`, 'red');
  log(`Success Rate: ${((passed / scenarios.length) * 100).toFixed(1)}%`, 
      failed === 0 ? 'green' : 'yellow');
  
  if (failed === 0) {
    log('\n✨ All integration tests passed! Auth and rate limiting work correctly together.', 'green');
  } else {
    log(`\n⚠️  ${failed} scenario(s) failed. Please review and fix the issues.`, 'red');
  }
  
  await prisma.$disconnect();
  process.exit(failed === 0 ? 0 : 1);
}

// Run tests
runIntegrationTests().catch(error => {
  log(`\n❌ Integration test suite error: ${error}`, 'red');
  process.exit(1);
});