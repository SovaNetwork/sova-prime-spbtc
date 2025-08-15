#!/usr/bin/env npx tsx

/**
 * Script to create the first admin user
 * Usage: npx tsx scripts/create-admin.ts <email> <password>
 */

import { prisma } from '../lib/prisma';
import { hashPassword, isValidEmail, isValidPassword } from '../lib/auth/utils';

async function createAdminUser(email: string, password: string) {
  try {
    // Validate email
    if (!isValidEmail(email)) {
      throw new Error('Invalid email format');
    }

    // Validate password
    const passwordValidation = isValidPassword(password);
    if (!passwordValidation.valid) {
      throw new Error(passwordValidation.message || 'Invalid password');
    }

    // Check if user already exists
    const existingUser = await prisma.adminUser.findUnique({
      where: { email: email.toLowerCase() },
    });

    if (existingUser) {
      throw new Error('User with this email already exists');
    }

    // Hash password
    const passwordHash = await hashPassword(password);

    // Create user
    const user = await prisma.adminUser.create({
      data: {
        email: email.toLowerCase(),
        passwordHash,
        role: 'SUPER_ADMIN', // First user is super admin
        isActive: true,
      },
      select: {
        id: true,
        email: true,
        role: true,
        isActive: true,
        createdAt: true,
      },
    });

    console.log('✅ Admin user created successfully!');
    console.log(`Email: ${user.email}`);
    console.log(`Role: ${user.role}`);
    console.log(`User ID: ${user.id}`);
    console.log(`Created at: ${user.createdAt}`);

  } catch (error) {
    console.error('❌ Error creating admin user:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// Get command line arguments
const email = process.argv[2];
const password = process.argv[3];

if (!email || !password) {
  console.error('Usage: npx tsx scripts/create-admin.ts <email> <password>');
  console.error('Example: npx tsx scripts/create-admin.ts admin@example.com MySecurePassword123!');
  process.exit(1);
}

// Run the script
createAdminUser(email, password);