#!/usr/bin/env node
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function testConnection() {
  try {
    console.log('🔄 Testing database connection...');
    
    // Test basic connection
    await prisma.$connect();
    console.log('✅ Connected to database');
    
    // Test query
    const networks = await prisma.sovaBtcNetwork.count();
    console.log(`✅ Found ${networks} networks in database`);
    
    // Test all tables exist
    const tables = [
      'sovaBtcNetwork',
      'sovaBtcDeployment', 
      'sovaBtcCollateral',
      'sovaBtcTokenRegistry',
      'sovaBtcDeploymentMetrics',
      'sovaBtcNetworkMetrics',
      'sovaBtcActivity'
    ];
    
    for (const table of tables) {
      try {
        await prisma[table].count();
        console.log(`✅ Table ${table} exists`);
      } catch (error) {
        console.log(`❌ Table ${table} does not exist or is inaccessible`);
      }
    }
    
    await prisma.$disconnect();
    console.log('✅ Database test complete');
    process.exit(0);
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    await prisma.$disconnect();
    process.exit(1);
  }
}

testConnection();