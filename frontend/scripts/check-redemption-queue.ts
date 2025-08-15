#!/usr/bin/env node

/**
 * Script to check redemption requests in the database
 */

import { PrismaClient } from '@prisma/client'
import dotenv from 'dotenv'

dotenv.config({ path: '.env.local' })

const prisma = new PrismaClient()

async function checkRedemptionQueue() {
  console.log('🔍 Checking redemption queue in database...\n')

  try {
    // Get all redemption requests
    const allRequests = await prisma.redemptionRequest.findMany({
      orderBy: { createdAt: 'desc' }
    })

    console.log(`Total redemption requests: ${allRequests.length}`)
    
    if (allRequests.length > 0) {
      console.log('\nRequests by status:')
      const statusCounts = allRequests.reduce((acc, req) => {
        acc[req.status] = (acc[req.status] || 0) + 1
        return acc
      }, {} as Record<string, number>)
      
      Object.entries(statusCounts).forEach(([status, count]) => {
        console.log(`  ${status}: ${count}`)
      })

      console.log('\nDeployment IDs found:')
      const deploymentIds = [...new Set(allRequests.map(r => r.deploymentId))]
      deploymentIds.forEach(id => {
        console.log(`  - ${id}`)
      })

      console.log('\nSample requests:')
      allRequests.slice(0, 3).forEach((req, i) => {
        console.log(`\n  Request ${i + 1}:`)
        console.log(`    ID: ${req.id}`)
        console.log(`    Deployment: ${req.deploymentId}`)
        console.log(`    User: ${req.userAddress}`)
        console.log(`    Status: ${req.status}`)
        console.log(`    Shares: ${req.shareAmount.toString()}`)
        console.log(`    Created: ${req.createdAt}`)
      })
    }

    // Check deployments
    console.log('\n📦 Checking deployments...')
    const deployments = await prisma.sovaBtcDeployment.findMany()
    
    console.log(`Total deployments: ${deployments.length}`)
    deployments.forEach(dep => {
      console.log(`  - ${dep.id} (Chain: ${dep.chainId}, Status: ${dep.status})`)
    })

    // If no deployments, create one
    if (deployments.length === 0) {
      console.log('\n⚠️  No deployments found. Creating default deployment...')
      
      const newDeployment = await prisma.sovaBtcDeployment.create({
        data: {
          id: 'base-sepolia-deployment',
          chainId: 84532, // Base Sepolia chain ID
          vaultStrategy: '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
          vaultToken: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
          priceOracle: '0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF',
          status: 'ACTIVE'
        }
      })
      
      console.log(`Created deployment: ${newDeployment.id}`)
    }

  } catch (error) {
    console.error('Error checking redemption queue:', error)
  } finally {
    await prisma.$disconnect()
  }
}

checkRedemptionQueue().catch(console.error)