#!/usr/bin/env tsx
/**
 * Authentication System Test Suite
 * 
 * Comprehensive testing for the admin authentication system
 * Tests login, logout, token refresh, role-based access, and security features
 * 
 * Usage: npx tsx scripts/test-auth-system.ts
 */

import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';
import * as jose from 'jose';

const prisma = new PrismaClient();

// Test configuration
const API_URL = process.env.API_URL || 'http://localhost:3000/api';
const TEST_USERS = [
  { email: 'superadmin@test.com', password: 'SuperAdmin123!', role: 'SUPER_ADMIN' },
  { email: 'admin@test.com', password: 'Admin123!', role: 'ADMIN' },
  { email: 'operator@test.com', password: 'Operator123!', role: 'OPERATOR' },
  { email: 'viewer@test.com', password: 'Viewer123!', role: 'VIEWER' }
];

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

// Test result tracking
let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

async function runTest(name: string, testFn: () => Promise<boolean>) {
  totalTests++;
  log(`\n📝 Testing: ${name}`, 'cyan');
  
  try {
    const result = await testFn();
    if (result) {
      passedTests++;
      log(`  ✅ Passed`, 'green');
      return true;
    } else {
      failedTests++;
      log(`  ❌ Failed`, 'red');
      return false;
    }
  } catch (error) {
    failedTests++;
    log(`  ❌ Error: ${error}`, 'red');
    return false;
  }
}

// Setup test users
async function setupTestUsers() {
  log('\n🔧 Setting up test users...', 'blue');
  
  for (const user of TEST_USERS) {
    try {
      // Check if user exists
      const existing = await prisma.adminUser.findUnique({
        where: { email: user.email }
      });
      
      if (!existing) {
        const passwordHash = await bcrypt.hash(user.password, 12);
        await prisma.adminUser.create({
          data: {
            email: user.email,
            passwordHash,
            role: user.role as any,
            isActive: true
          }
        });
        log(`  Created ${user.email} (${user.role})`, 'gray');
      } else {
        log(`  ${user.email} already exists`, 'gray');
      }
    } catch (error) {
      log(`  Failed to create ${user.email}: ${error}`, 'red');
    }
  }
}

// Cleanup test users
async function cleanupTestUsers() {
  log('\n🧹 Cleaning up test users...', 'blue');
  
  // Delete sessions first
  await prisma.adminSession.deleteMany({
    where: {
      user: {
        email: { in: TEST_USERS.map(u => u.email) }
      }
    }
  });
  
  // Delete users
  await prisma.adminUser.deleteMany({
    where: {
      email: { in: TEST_USERS.map(u => u.email) }
    }
  });
  
  log('  Test users cleaned up', 'gray');
}

// Test functions
async function testLogin(email: string, password: string, shouldSucceed: boolean): Promise<boolean> {
  const response = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  
  if (shouldSucceed) {
    if (response.ok) {
      const data = await response.json();
      if (data.accessToken && data.refreshToken && data.user) {
        log(`    Login successful for ${email}`, 'gray');
        return true;
      }
    }
    log(`    Login failed unexpectedly for ${email}`, 'red');
    return false;
  } else {
    if (!response.ok) {
      log(`    Login correctly rejected for ${email}`, 'gray');
      return true;
    }
    log(`    Login should have failed for ${email}`, 'red');
    return false;
  }
}

async function testTokenValidation(token: string, shouldBeValid: boolean): Promise<boolean> {
  const response = await fetch(`${API_URL}/auth/me`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  if (shouldBeValid) {
    if (response.ok) {
      const data = await response.json();
      if (data.user) {
        log(`    Token valid for user ${data.user.email}`, 'gray');
        return true;
      }
    }
    log(`    Token validation failed unexpectedly`, 'red');
    return false;
  } else {
    if (!response.ok) {
      log(`    Token correctly rejected`, 'gray');
      return true;
    }
    log(`    Invalid token should have been rejected`, 'red');
    return false;
  }
}

async function testTokenRefresh(refreshToken: string): Promise<boolean> {
  const response = await fetch(`${API_URL}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken })
  });
  
  if (response.ok) {
    const data = await response.json();
    if (data.accessToken && data.refreshToken) {
      log(`    Token refresh successful`, 'gray');
      return true;
    }
  }
  
  log(`    Token refresh failed`, 'red');
  return false;
}

async function testLogout(token: string): Promise<boolean> {
  const response = await fetch(`${API_URL}/auth/logout`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  if (response.ok) {
    log(`    Logout successful`, 'gray');
    
    // Verify token is invalidated
    const checkResponse = await fetch(`${API_URL}/auth/me`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    
    if (!checkResponse.ok) {
      log(`    Token correctly invalidated after logout`, 'gray');
      return true;
    } else {
      log(`    Token still valid after logout!`, 'red');
      return false;
    }
  }
  
  log(`    Logout failed`, 'red');
  return false;
}

async function testRoleBasedAccess(token: string, role: string, endpoint: string, method: string, shouldSucceed: boolean): Promise<boolean> {
  const response = await fetch(`${API_URL}${endpoint}`, {
    method,
    headers: { 
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
  
  if (shouldSucceed) {
    if (response.ok || response.status === 404) { // 404 is ok for GET requests on empty resources
      log(`    ${role} correctly accessed ${endpoint}`, 'gray');
      return true;
    }
    log(`    ${role} should have access to ${endpoint} but was denied`, 'red');
    return false;
  } else {
    if (response.status === 403 || response.status === 401) {
      log(`    ${role} correctly denied access to ${endpoint}`, 'gray');
      return true;
    }
    log(`    ${role} should not have access to ${endpoint} but was allowed`, 'red');
    return false;
  }
}

async function testBruteForceProtection(): Promise<boolean> {
  const testEmail = 'bruteforce@test.com';
  const wrongPassword = 'WrongPassword123!';
  let blockedAfterAttempts = false;
  
  // Try 6 login attempts (should be blocked after 5)
  for (let i = 1; i <= 6; i++) {
    const response = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, password: wrongPassword })
    });
    
    if (response.status === 429) {
      log(`    Blocked after ${i} attempts`, 'gray');
      blockedAfterAttempts = true;
      
      // Check for rate limit headers
      const retryAfter = response.headers.get('Retry-After');
      const blockedUntil = response.headers.get('X-RateLimit-Blocked-Until');
      
      if (retryAfter && blockedUntil) {
        log(`    Rate limit headers present`, 'gray');
        return true;
      } else {
        log(`    Missing rate limit headers`, 'red');
        return false;
      }
    }
  }
  
  if (!blockedAfterAttempts) {
    log(`    Not blocked after 6 attempts!`, 'red');
    return false;
  }
  
  return true;
}

async function testPasswordStrength(): Promise<boolean> {
  const weakPasswords = ['123456', 'password', 'short', 'NoNumbers!', 'nospecialchars123'];
  const strongPassword = 'StrongP@ssw0rd123!';
  
  // Test weak passwords (should fail)
  for (const password of weakPasswords) {
    const response = await fetch(`${API_URL}/admin/users`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${await getTestToken('SUPER_ADMIN')}`
      },
      body: JSON.stringify({ 
        email: `weak${Math.random()}@test.com`, 
        password,
        role: 'VIEWER'
      })
    });
    
    if (response.ok) {
      log(`    Weak password accepted: ${password}`, 'red');
      return false;
    }
  }
  
  log(`    All weak passwords correctly rejected`, 'gray');
  
  // Test strong password (should succeed)
  const response = await fetch(`${API_URL}/admin/users`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getTestToken('SUPER_ADMIN')}`
    },
    body: JSON.stringify({ 
      email: `strong${Math.random()}@test.com`, 
      password: strongPassword,
      role: 'VIEWER'
    })
  });
  
  if (response.ok) {
    log(`    Strong password accepted`, 'gray');
    return true;
  } else {
    log(`    Strong password rejected unexpectedly`, 'red');
    return false;
  }
}

// Helper to get test token for a specific role
async function getTestToken(role: string): Promise<string> {
  const user = TEST_USERS.find(u => u.role === role);
  if (!user) throw new Error(`No test user for role ${role}`);
  
  const response = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: user.email, password: user.password })
  });
  
  if (response.ok) {
    const data = await response.json();
    return data.accessToken;
  }
  
  throw new Error(`Failed to get token for ${role}`);
}

// Main test runner
async function runTests() {
  log('\n🧪 Authentication System Test Suite', 'blue');
  log('====================================', 'blue');
  
  try {
    // Setup
    await setupTestUsers();
    
    // Test 1: Valid login
    await runTest('Valid login credentials', async () => {
      return await testLogin('superadmin@test.com', 'SuperAdmin123!', true);
    });
    
    // Test 2: Invalid login
    await runTest('Invalid login credentials', async () => {
      return await testLogin('superadmin@test.com', 'WrongPassword', false);
    });
    
    // Test 3: Token validation
    await runTest('Token validation', async () => {
      const token = await getTestToken('SUPER_ADMIN');
      return await testTokenValidation(token, true);
    });
    
    // Test 4: Invalid token
    await runTest('Invalid token rejection', async () => {
      return await testTokenValidation('invalid.token.here', false);
    });
    
    // Test 5: Token refresh
    await runTest('Token refresh', async () => {
      const response = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          email: 'superadmin@test.com', 
          password: 'SuperAdmin123!' 
        })
      });
      const data = await response.json();
      return await testTokenRefresh(data.refreshToken);
    });
    
    // Test 6: Logout
    await runTest('Logout and token invalidation', async () => {
      const token = await getTestToken('ADMIN');
      return await testLogout(token);
    });
    
    // Test 7: Role-based access - SUPER_ADMIN
    await runTest('SUPER_ADMIN can access admin users endpoint', async () => {
      const token = await getTestToken('SUPER_ADMIN');
      return await testRoleBasedAccess(token, 'SUPER_ADMIN', '/admin/users', 'GET', true);
    });
    
    // Test 8: Role-based access - ADMIN denied
    await runTest('ADMIN cannot access admin users endpoint', async () => {
      const token = await getTestToken('ADMIN');
      return await testRoleBasedAccess(token, 'ADMIN', '/admin/users', 'GET', false);
    });
    
    // Test 9: Role-based access - OPERATOR
    await runTest('OPERATOR can process redemptions', async () => {
      const token = await getTestToken('OPERATOR');
      return await testRoleBasedAccess(token, 'OPERATOR', '/redemptions/test/process', 'POST', true);
    });
    
    // Test 10: Role-based access - VIEWER denied
    await runTest('VIEWER cannot process redemptions', async () => {
      const token = await getTestToken('VIEWER');
      return await testRoleBasedAccess(token, 'VIEWER', '/redemptions/test/process', 'POST', false);
    });
    
    // Test 11: Brute force protection
    await runTest('Brute force protection after 5 attempts', async () => {
      return await testBruteForceProtection();
    });
    
    // Test 12: Password strength validation
    await runTest('Password strength requirements', async () => {
      return await testPasswordStrength();
    });
    
    // Test 13: Session management
    await runTest('Multiple sessions per user', async () => {
      // Login twice with same user
      const response1 = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          email: 'operator@test.com', 
          password: 'Operator123!' 
        })
      });
      
      const response2 = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          email: 'operator@test.com', 
          password: 'Operator123!' 
        })
      });
      
      if (response1.ok && response2.ok) {
        const data1 = await response1.json();
        const data2 = await response2.json();
        
        // Both tokens should be valid
        const valid1 = await testTokenValidation(data1.accessToken, true);
        const valid2 = await testTokenValidation(data2.accessToken, true);
        
        if (valid1 && valid2) {
          log(`    Multiple sessions working correctly`, 'gray');
          return true;
        }
      }
      
      log(`    Multiple sessions failed`, 'red');
      return false;
    });
    
    // Test 14: Expired token handling
    await runTest('Expired token rejection', async () => {
      // Create an expired token
      const secret = new TextEncoder().encode(process.env.JWT_SECRET || 'test-secret');
      const expiredToken = await new jose.SignJWT({ 
        userId: 'test', 
        email: 'test@test.com',
        role: 'VIEWER'
      })
        .setProtectedHeader({ alg: 'HS256' })
        .setExpirationTime('0s')
        .sign(secret);
      
      return await testTokenValidation(expiredToken, false);
    });
    
    // Test 15: User deactivation
    await runTest('Deactivated user cannot login', async () => {
      // Create a user and deactivate them
      const testEmail = `deactivated${Math.random()}@test.com`;
      const passwordHash = await bcrypt.hash('TestPassword123!', 12);
      
      const user = await prisma.adminUser.create({
        data: {
          email: testEmail,
          passwordHash,
          role: 'VIEWER',
          isActive: false
        }
      });
      
      const result = await testLogin(testEmail, 'TestPassword123!', false);
      
      // Cleanup
      await prisma.adminUser.delete({ where: { id: user.id } });
      
      return result;
    });
    
  } catch (error) {
    log(`\n❌ Test suite error: ${error}`, 'red');
  } finally {
    // Cleanup
    await cleanupTestUsers();
    await prisma.$disconnect();
  }
  
  // Summary
  log('\n' + '='.repeat(50), 'blue');
  log(`📊 Test Results Summary`, 'blue');
  log('='.repeat(50), 'blue');
  log(`Total Tests: ${totalTests}`, 'cyan');
  log(`Passed: ${passedTests}`, 'green');
  log(`Failed: ${failedTests}`, 'red');
  log(`Success Rate: ${((passedTests / totalTests) * 100).toFixed(1)}%`, 
      failedTests === 0 ? 'green' : 'yellow');
  
  if (failedTests === 0) {
    log('\n✨ All tests passed! Authentication system is working correctly.', 'green');
  } else {
    log(`\n⚠️  ${failedTests} test(s) failed. Please review and fix the issues.`, 'red');
  }
  
  process.exit(failedTests === 0 ? 0 : 1);
}

// Run tests
runTests().catch(console.error);