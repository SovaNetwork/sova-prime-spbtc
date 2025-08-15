#!/usr/bin/env node

/**
 * Rate Limiting Testing Script
 * 
 * This script tests the rate limiting functionality of the SovaBTC vault API endpoints.
 * It validates that rate limits are properly enforced and brute force protection works.
 */

import { promises as fs } from 'fs';
import { join } from 'path';

interface TestResult {
  test: string;
  passed: boolean;
  message: string;
  duration: number;
  statusCode?: number;
  headers?: Record<string, string>;
}

interface RateLimitHeaders {
  'x-ratelimit-limit'?: string;
  'x-ratelimit-remaining'?: string;
  'x-ratelimit-reset'?: string;
  'x-ratelimit-blocked-until'?: string;
  'retry-after'?: string;
}

class RateLimitTester {
  private baseUrl: string;
  private results: TestResult[] = [];

  constructor(baseUrl: string = 'http://localhost:3000') {
    this.baseUrl = baseUrl;
  }

  private async makeRequest(
    endpoint: string,
    options: RequestInit = {},
    headers: Record<string, string> = {}
  ): Promise<Response> {
    const url = `${this.baseUrl}${endpoint}`;
    
    return fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
        ...options.headers,
      },
    });
  }

  private extractRateLimitHeaders(response: Response): RateLimitHeaders {
    const headers: RateLimitHeaders = {};
    
    const rateLimitKeys = [
      'x-ratelimit-limit',
      'x-ratelimit-remaining', 
      'x-ratelimit-reset',
      'x-ratelimit-blocked-until',
      'retry-after'
    ];

    rateLimitKeys.forEach(key => {
      const value = response.headers.get(key);
      if (value) {
        headers[key as keyof RateLimitHeaders] = value;
      }
    });

    return headers;
  }

  private addResult(test: string, passed: boolean, message: string, duration: number, response?: Response) {
    const result: TestResult = {
      test,
      passed,
      message,
      duration,
    };

    if (response) {
      result.statusCode = response.status;
      result.headers = Object.fromEntries(response.headers.entries());
    }

    this.results.push(result);
  }

  // Test public read endpoint rate limits (100 requests/minute)
  async testPublicReadLimits(): Promise<void> {
    console.log('🔍 Testing public read endpoint rate limits...');
    
    const startTime = Date.now();
    let successCount = 0;
    let rateLimitHit = false;

    // Make 105 requests to trigger rate limit
    for (let i = 1; i <= 105; i++) {
      try {
        const response = await this.makeRequest('/api/networks');
        
        if (response.status === 200) {
          successCount++;
        } else if (response.status === 429) {
          rateLimitHit = true;
          const headers = this.extractRateLimitHeaders(response);
          
          this.addResult(
            'Public Read Rate Limit',
            true,
            `Rate limit hit after ${i} requests. Limit: ${headers['x-ratelimit-limit']}, Remaining: ${headers['x-ratelimit-remaining']}`,
            Date.now() - startTime,
            response
          );
          break;
        }
      } catch (error) {
        this.addResult(
          'Public Read Rate Limit',
          false,
          `Request failed: ${error}`,
          Date.now() - startTime
        );
        return;
      }
    }

    if (!rateLimitHit) {
      this.addResult(
        'Public Read Rate Limit',
        false,
        `Rate limit not hit after 105 requests. Expected limit: 100`,
        Date.now() - startTime
      );
    }
  }

  // Test write endpoint rate limits (20 requests/minute)
  async testWriteLimits(): Promise<void> {
    console.log('✏️ Testing write endpoint rate limits...');
    
    const startTime = Date.now();
    let successCount = 0;
    let rateLimitHit = false;

    // Make 25 POST requests to trigger rate limit
    for (let i = 1; i <= 25; i++) {
      try {
        const response = await this.makeRequest('/api/collaterals', {
          method: 'POST',
          body: JSON.stringify({
            symbol: 'TEST',
            name: 'Test Token',
            address: '0x1234567890123456789012345678901234567890',
            decimals: 18
          })
        });
        
        // We expect 400/401 for invalid data, but not 429 until limit is hit
        if (response.status !== 429) {
          successCount++;
        } else {
          rateLimitHit = true;
          const headers = this.extractRateLimitHeaders(response);
          
          this.addResult(
            'Write Endpoint Rate Limit',
            true,
            `Rate limit hit after ${i} requests. Limit: ${headers['x-ratelimit-limit']}, Remaining: ${headers['x-ratelimit-remaining']}`,
            Date.now() - startTime,
            response
          );
          break;
        }
      } catch (error) {
        this.addResult(
          'Write Endpoint Rate Limit',
          false,
          `Request failed: ${error}`,
          Date.now() - startTime
        );
        return;
      }
    }

    if (!rateLimitHit) {
      this.addResult(
        'Write Endpoint Rate Limit',
        false,
        `Rate limit not hit after 25 requests. Expected limit: 20`,
        Date.now() - startTime
      );
    }
  }

  // Test auth endpoint brute force protection (5 requests/minute)
  async testBruteForceProtection(): Promise<void> {
    console.log('🔒 Testing brute force protection on login endpoint...');
    
    const startTime = Date.now();
    let blockedResponse: Response | null = null;

    // Make 6 failed login attempts to trigger brute force protection
    for (let i = 1; i <= 6; i++) {
      try {
        const response = await this.makeRequest('/api/auth/login', {
          method: 'POST',
          body: JSON.stringify({
            email: 'test@example.com',
            password: 'wrongpassword'
          })
        });
        
        if (response.status === 429) {
          blockedResponse = response;
          const headers = this.extractRateLimitHeaders(response);
          const responseData = await response.json();
          
          this.addResult(
            'Brute Force Protection',
            true,
            `Brute force protection triggered after ${i} attempts. ${responseData.message || 'IP blocked'}`,
            Date.now() - startTime,
            response
          );
          
          // Test that subsequent requests are also blocked
          const followUpResponse = await this.makeRequest('/api/auth/login', {
            method: 'POST',
            body: JSON.stringify({
              email: 'test@example.com',
              password: 'wrongpassword'
            })
          });
          
          if (followUpResponse.status === 429) {
            this.addResult(
              'Brute Force Persistence',
              true,
              'Subsequent requests correctly blocked',
              Date.now() - startTime,
              followUpResponse
            );
          }
          
          break;
        }
      } catch (error) {
        this.addResult(
          'Brute Force Protection',
          false,
          `Request failed: ${error}`,
          Date.now() - startTime
        );
        return;
      }
    }

    if (!blockedResponse) {
      this.addResult(
        'Brute Force Protection',
        false,
        'Brute force protection not triggered after 6 failed login attempts',
        Date.now() - startTime
      );
    }
  }

  // Test admin endpoint rate limits (50 requests/minute)
  async testAdminLimits(): Promise<void> {
    console.log('👤 Testing admin endpoint rate limits...');
    
    const startTime = Date.now();
    let rateLimitHit = false;

    // Make 55 requests to admin endpoint to trigger rate limit
    for (let i = 1; i <= 55; i++) {
      try {
        const response = await this.makeRequest('/api/admin/rate-limits');
        
        if (response.status === 429) {
          rateLimitHit = true;
          const headers = this.extractRateLimitHeaders(response);
          
          this.addResult(
            'Admin Endpoint Rate Limit',
            true,
            `Admin rate limit hit after ${i} requests. Limit: ${headers['x-ratelimit-limit']}, Remaining: ${headers['x-ratelimit-remaining']}`,
            Date.now() - startTime,
            response
          );
          break;
        }
      } catch (error) {
        this.addResult(
          'Admin Endpoint Rate Limit',
          false,
          `Request failed: ${error}`,
          Date.now() - startTime
        );
        return;
      }
    }

    if (!rateLimitHit) {
      this.addResult(
        'Admin Endpoint Rate Limit',
        false,
        `Admin rate limit not hit after 55 requests. Expected limit: 50`,
        Date.now() - startTime
      );
    }
  }

  // Test rate limit headers presence
  async testRateLimitHeaders(): Promise<void> {
    console.log('📊 Testing rate limit headers...');
    
    const startTime = Date.now();
    
    try {
      const response = await this.makeRequest('/api/networks');
      const headers = this.extractRateLimitHeaders(response);
      
      const requiredHeaders = ['x-ratelimit-limit', 'x-ratelimit-remaining', 'x-ratelimit-reset'];
      const missingHeaders = requiredHeaders.filter(header => !headers[header as keyof RateLimitHeaders]);
      
      if (missingHeaders.length === 0) {
        this.addResult(
          'Rate Limit Headers',
          true,
          `All required headers present: ${Object.keys(headers).join(', ')}`,
          Date.now() - startTime,
          response
        );
      } else {
        this.addResult(
          'Rate Limit Headers',
          false,
          `Missing headers: ${missingHeaders.join(', ')}`,
          Date.now() - startTime,
          response
        );
      }
    } catch (error) {
      this.addResult(
        'Rate Limit Headers',
        false,
        `Request failed: ${error}`,
        Date.now() - startTime
      );
    }
  }

  // Test different IP addresses (simulated)
  async testDifferentIPs(): Promise<void> {
    console.log('🌐 Testing different IP rate limiting...');
    
    const startTime = Date.now();
    const testIPs = ['192.168.1.1', '10.0.0.1', '172.16.0.1'];
    
    try {
      // Make requests from different IPs
      for (const ip of testIPs) {
        const response = await this.makeRequest('/api/networks', {}, {
          'X-Forwarded-For': ip
        });
        
        const headers = this.extractRateLimitHeaders(response);
        
        if (response.status === 200 && headers['x-ratelimit-remaining']) {
          this.addResult(
            `IP-based Rate Limiting (${ip})`,
            true,
            `Request successful, remaining: ${headers['x-ratelimit-remaining']}`,
            Date.now() - startTime,
            response
          );
        }
      }
    } catch (error) {
      this.addResult(
        'IP-based Rate Limiting',
        false,
        `Request failed: ${error}`,
        Date.now() - startTime
      );
    }
  }

  // Run all tests
  async runAllTests(): Promise<void> {
    console.log('🚀 Starting rate limit tests...\n');
    
    const tests = [
      () => this.testRateLimitHeaders(),
      () => this.testDifferentIPs(),
      () => this.testPublicReadLimits(),
      () => this.testWriteLimits(),
      () => this.testAdminLimits(),
      () => this.testBruteForceProtection(),
    ];

    for (const test of tests) {
      try {
        await test();
        // Wait between tests to avoid interference
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (error) {
        console.error(`Test failed: ${error}`);
      }
    }
  }

  // Generate test report
  generateReport(): string {
    const totalTests = this.results.length;
    const passedTests = this.results.filter(r => r.passed).length;
    const failedTests = totalTests - passedTests;
    
    let report = '\n' + '='.repeat(60) + '\n';
    report += '           RATE LIMITING TEST REPORT\n';
    report += '='.repeat(60) + '\n\n';
    
    report += `Total Tests: ${totalTests}\n`;
    report += `Passed: ${passedTests} ✅\n`;
    report += `Failed: ${failedTests} ❌\n`;
    report += `Success Rate: ${((passedTests / totalTests) * 100).toFixed(1)}%\n\n`;
    
    report += 'DETAILED RESULTS:\n';
    report += '-'.repeat(60) + '\n';
    
    this.results.forEach((result, index) => {
      const status = result.passed ? '✅ PASS' : '❌ FAIL';
      const duration = result.duration.toString().padStart(4, ' ');
      
      report += `${(index + 1).toString().padStart(2, ' ')}. ${status} | ${duration}ms | ${result.test}\n`;
      report += `    ${result.message}\n`;
      
      if (result.statusCode) {
        report += `    Status: ${result.statusCode}\n`;
      }
      
      if (result.headers && (result.headers['x-ratelimit-limit'] || result.headers['retry-after'])) {
        const rateLimitInfo = [
          result.headers['x-ratelimit-limit'] && `Limit: ${result.headers['x-ratelimit-limit']}`,
          result.headers['x-ratelimit-remaining'] && `Remaining: ${result.headers['x-ratelimit-remaining']}`,
          result.headers['retry-after'] && `Retry After: ${result.headers['retry-after']}s`
        ].filter(Boolean).join(', ');
        
        if (rateLimitInfo) {
          report += `    ${rateLimitInfo}\n`;
        }
      }
      
      report += '\n';
    });
    
    report += '='.repeat(60) + '\n';
    
    return report;
  }

  // Save report to file
  async saveReport(filename: string = 'rate-limit-test-report.txt'): Promise<void> {
    const report = this.generateReport();
    const filepath = join(process.cwd(), filename);
    
    try {
      await fs.writeFile(filepath, report, 'utf8');
      console.log(`📄 Test report saved to: ${filepath}`);
    } catch (error) {
      console.error(`Failed to save report: ${error}`);
    }
  }

  // Get test results
  getResults(): TestResult[] {
    return this.results;
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  const baseUrl = args[0] || 'http://localhost:3000';
  
  console.log(`Testing rate limits for: ${baseUrl}`);
  
  const tester = new RateLimitTester(baseUrl);
  
  try {
    await tester.runAllTests();
    
    // Display results
    const report = tester.generateReport();
    console.log(report);
    
    // Save report
    await tester.saveReport();
    
    // Exit with appropriate code
    const results = tester.getResults();
    const hasFailures = results.some(r => !r.passed);
    process.exit(hasFailures ? 1 : 0);
    
  } catch (error) {
    console.error('❌ Test execution failed:', error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

export { RateLimitTester, type TestResult };