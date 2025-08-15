import { NextRequest, NextResponse } from 'next/server';
import { PrismaClient } from '@prisma/client';

// Global Prisma instance
let prisma: PrismaClient;

if (process.env.NODE_ENV === 'production') {
  prisma = new PrismaClient();
} else {
  // In development, use a global variable to prevent multiple instances
  if (!(global as any).prisma) {
    (global as any).prisma = new PrismaClient();
  }
  prisma = (global as any).prisma;
}

// Rate limit configurations for different endpoint types
export const RATE_LIMIT_CONFIGS = {
  PUBLIC_READ: {
    windowMs: 60 * 1000, // 1 minute
    maxRequests: 100,
    name: 'public_read'
  },
  WRITE: {
    windowMs: 60 * 1000, // 1 minute
    maxRequests: 20,
    name: 'write'
  },
  ADMIN: {
    windowMs: 60 * 1000, // 1 minute
    maxRequests: 50,
    name: 'admin'
  },
  AUTH: {
    windowMs: 60 * 1000, // 1 minute
    maxRequests: 5,
    name: 'auth'
  },
  BRUTE_FORCE: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    maxRequests: 5,
    blockDuration: 60 * 60 * 1000, // 1 hour block
    name: 'brute_force'
  }
} as const;

export type RateLimitType = keyof typeof RATE_LIMIT_CONFIGS;

// In-memory rate limit store (for production, consider Redis)
interface RateLimitEntry {
  count: number;
  resetTime: number;
  blocked?: boolean;
  blockUntil?: number;
}

const rateLimitStore = new Map<string, RateLimitEntry>();

// Helper to get client IP
export function getClientIP(request: NextRequest): string {
  const forwarded = request.headers.get('x-forwarded-for');
  const realIP = request.headers.get('x-real-ip');
  const cfConnectingIP = request.headers.get('cf-connecting-ip');
  
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }
  if (realIP) {
    return realIP;
  }
  if (cfConnectingIP) {
    return cfConnectingIP;
  }
  
  return 'unknown';
}

// Helper to extract user ID from JWT token
export async function getUserIdFromRequest(request: NextRequest): Promise<string | null> {
  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    const token = authHeader.substring(7);
    // Import jose dynamically to avoid issues
    const { jwtVerify } = await import('jose');
    const secret = new TextEncoder().encode(process.env.JWT_SECRET || 'default-secret');
    
    const { payload } = await jwtVerify(token, secret);
    return payload.userId as string || null;
  } catch {
    return null;
  }
}

// Check if user is SUPER_ADMIN (bypass rate limits)
// With wallet-based auth, we don't have admin roles anymore
export async function isSuperAdmin(request: NextRequest): Promise<boolean> {
  return false; // No admin roles with wallet-based auth
}

// Log rate limit violation to database
async function logViolation(
  ip: string,
  endpoint: string,
  userAgent: string | null,
  userId: string | null,
  blocked: boolean = false,
  blockUntil: Date | null = null
) {
  try {
    // Check if recent violation exists
    const recentViolation = await prisma.rateLimitViolation.findFirst({
      where: {
        ip,
        endpoint,
        timestamp: {
          gte: new Date(Date.now() - 60 * 1000) // Last minute
        }
      },
      orderBy: { timestamp: 'desc' }
    });

    if (recentViolation) {
      // Update existing violation
      await prisma.rateLimitViolation.update({
        where: { id: recentViolation.id },
        data: {
          count: recentViolation.count + 1,
          blocked,
          blockUntil,
          updatedAt: new Date()
        }
      });
    } else {
      // Create new violation
      await prisma.rateLimitViolation.create({
        data: {
          ip,
          endpoint,
          userAgent,
          userId,
          count: 1,
          blocked,
          blockUntil
        }
      });
    }
  } catch (error) {
    console.error('Failed to log rate limit violation:', error);
  }
}

// Main rate limiting function
export async function rateLimit(
  request: NextRequest,
  limitType: RateLimitType,
  customKey?: string
): Promise<{
  success: boolean;
  remaining: number;
  reset: number;
  blocked?: boolean;
  blockUntil?: number;
}> {
  const config = RATE_LIMIT_CONFIGS[limitType];
  const ip = getClientIP(request);
  const endpoint = request.nextUrl.pathname;
  const userAgent = request.headers.get('user-agent');
  const userId = await getUserIdFromRequest(request);

  // Check if user is SUPER_ADMIN (bypass all limits)
  if (await isSuperAdmin(request)) {
    return {
      success: true,
      remaining: config.maxRequests,
      reset: Date.now() + config.windowMs
    };
  }

  // Create rate limit key
  const key = customKey || `${limitType}:${ip}:${endpoint}`;
  const now = Date.now();

  // Get or create rate limit entry
  let entry = rateLimitStore.get(key);
  
  if (!entry || now > entry.resetTime) {
    entry = {
      count: 0,
      resetTime: now + config.windowMs
    };
  }

  // Check if currently blocked
  if (entry.blocked && entry.blockUntil && now < entry.blockUntil) {
    await logViolation(ip, endpoint, userAgent, userId, true, new Date(entry.blockUntil));
    return {
      success: false,
      remaining: 0,
      reset: entry.resetTime,
      blocked: true,
      blockUntil: entry.blockUntil
    };
  }

  // Clear block if expired
  if (entry.blocked && entry.blockUntil && now >= entry.blockUntil) {
    entry.blocked = false;
    entry.blockUntil = undefined;
  }

  // Increment counter
  entry.count++;

  // Check if limit exceeded
  if (entry.count > config.maxRequests) {
    // Apply blocking for brute force protection
    if (limitType === 'BRUTE_FORCE' && 'blockDuration' in config) {
      entry.blocked = true;
      entry.blockUntil = now + config.blockDuration;
    }

    rateLimitStore.set(key, entry);
    
    await logViolation(
      ip, 
      endpoint, 
      userAgent, 
      userId, 
      entry.blocked,
      entry.blockUntil ? new Date(entry.blockUntil) : null
    );

    return {
      success: false,
      remaining: 0,
      reset: entry.resetTime,
      blocked: entry.blocked,
      blockUntil: entry.blockUntil
    };
  }

  rateLimitStore.set(key, entry);

  return {
    success: true,
    remaining: config.maxRequests - entry.count,
    reset: entry.resetTime
  };
}

// Cleanup expired entries (call periodically)
export function cleanupRateLimitStore() {
  const now = Date.now();
  for (const [key, entry] of rateLimitStore.entries()) {
    if (now > entry.resetTime && (!entry.blocked || (entry.blockUntil && now > entry.blockUntil))) {
      rateLimitStore.delete(key);
    }
  }
}

// Set up periodic cleanup
if (typeof setInterval !== 'undefined') {
  setInterval(cleanupRateLimitStore, 60 * 1000); // Every minute
}

// Rate limit middleware wrapper for API routes
export function withRateLimit(limitType: RateLimitType, customKey?: string) {
  return function (handler: (req: NextRequest) => Promise<NextResponse>) {
    return async function (req: NextRequest): Promise<NextResponse> {
      const result = await rateLimit(req, limitType, customKey);

      if (!result.success) {
        const headers = new Headers({
          'X-RateLimit-Limit': RATE_LIMIT_CONFIGS[limitType].maxRequests.toString(),
          'X-RateLimit-Remaining': '0',
          'X-RateLimit-Reset': Math.ceil(result.reset / 1000).toString(),
          'Retry-After': Math.ceil((result.reset - Date.now()) / 1000).toString()
        });

        if (result.blocked && result.blockUntil) {
          headers.set('X-RateLimit-Blocked-Until', Math.ceil(result.blockUntil / 1000).toString());
          
          return NextResponse.json(
            {
              error: 'Rate limit exceeded - temporarily blocked',
              message: `Too many requests. Blocked until ${new Date(result.blockUntil).toISOString()}`,
              blockedUntil: new Date(result.blockUntil).toISOString()
            },
            { status: 429, headers }
          );
        }

        return NextResponse.json(
          {
            error: 'Rate limit exceeded',
            message: `Too many requests. Try again in ${Math.ceil((result.reset - Date.now()) / 1000)} seconds.`
          },
          { status: 429, headers }
        );
      }

      // Add rate limit headers to successful responses
      const response = await handler(req);
      
      response.headers.set('X-RateLimit-Limit', RATE_LIMIT_CONFIGS[limitType].maxRequests.toString());
      response.headers.set('X-RateLimit-Remaining', result.remaining.toString());
      response.headers.set('X-RateLimit-Reset', Math.ceil(result.reset / 1000).toString());

      return response;
    };
  };
}

// Determine rate limit type based on endpoint
export function getRateLimitType(pathname: string, method: string): RateLimitType {
  // Auth endpoints (strictest)
  if (pathname.startsWith('/api/auth')) {
    return 'AUTH';
  }

  // Admin endpoints
  if (pathname.startsWith('/api/admin')) {
    return 'ADMIN';
  }

  // Write operations
  if (method === 'POST' || method === 'PUT' || method === 'PATCH' || method === 'DELETE') {
    return 'WRITE';
  }

  // Default to public read
  return 'PUBLIC_READ';
}

export { prisma };