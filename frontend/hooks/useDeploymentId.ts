'use client'

import { useState, useEffect } from 'react'
import { useChainId } from 'wagmi'

export function useDeploymentId() {
  const chainId = useChainId()
  const [deploymentId, setDeploymentId] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    const fetchDeploymentId = async () => {
      try {
        // Try to fetch the deployment for the current chain
        const response = await fetch(`/api/deployments/${chainId}`)
        
        if (response.ok) {
          const data = await response.json()
          if (data && data.id) {
            setDeploymentId(data.id)
            console.log('Using deployment ID from chain query:', data.id)
          } else {
            // Fallback - try to get any deployment
            const allDeploymentsResponse = await fetch('/api/deployments')
            if (allDeploymentsResponse.ok) {
              const deployments = await allDeploymentsResponse.json()
              if (deployments && deployments.length > 0) {
                setDeploymentId(deployments[0].id)
                console.log('Using first deployment found:', deployments[0].id)
              } else {
                // Hardcode the known deployment ID from database
                setDeploymentId('cme9bhsmc0002kf6906z13r2d')
                console.log('Using hardcoded deployment ID')
              }
            } else {
              // Hardcode the known deployment ID from database
              setDeploymentId('cme9bhsmc0002kf6906z13r2d')
              console.log('Using hardcoded deployment ID (API failed)')
            }
          }
        } else {
          // If the API call fails, try to get any deployment
          const allDeploymentsResponse = await fetch('/api/deployments')
          if (allDeploymentsResponse.ok) {
            const deployments = await allDeploymentsResponse.json()
            if (deployments && deployments.length > 0) {
              // Use the first deployment found
              setDeploymentId(deployments[0].id)
              console.log('Using first deployment from all deployments:', deployments[0].id)
            } else {
              // Hardcode the known deployment ID from database
              setDeploymentId('cme9bhsmc0002kf6906z13r2d')
              console.log('Using hardcoded deployment ID (no deployments)')
            }
          } else {
            // Hardcode the known deployment ID from database
            setDeploymentId('cme9bhsmc0002kf6906z13r2d')
            console.log('Using hardcoded deployment ID (all APIs failed)')
          }
        }
      } catch (error) {
        console.error('Error fetching deployment ID:', error)
        // Hardcode the known deployment ID from database
        setDeploymentId('cme9bhsmc0002kf6906z13r2d')
        console.log('Using hardcoded deployment ID (error caught)')
      } finally {
        setIsLoading(false)
      }
    }

    fetchDeploymentId()
  }, [chainId])

  return { deploymentId, isLoading }
}