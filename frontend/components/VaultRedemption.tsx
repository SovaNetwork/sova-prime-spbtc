'use client'

import { useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { GlassCard } from '@/components/GlassCard'
import { RedemptionRequestForm } from './RedemptionRequestForm'
import { UserRedemptionRequests } from './UserRedemptionRequests'
import { ERC20_ABI } from '@/lib/abis'
import { AlertTriangle, Info } from 'lucide-react'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

interface VaultRedemptionProps {
  vaultAddress: `0x${string}`
  deploymentId: string
  chainId: number
}

export function VaultRedemption({
  vaultAddress,
  deploymentId,
  chainId,
}: VaultRedemptionProps) {
  const { address } = useAccount()
  const [refreshTrigger, setRefreshTrigger] = useState(0)

  // Read user's vault share balance
  const { data: shareBalance = 0n } = useReadContract({
    address: vaultAddress,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })

  // Read current share price (assets per share)
  const { data: currentSharePrice = 0n } = useReadContract({
    address: vaultAddress,
    abi: [
      {
        inputs: [{ name: 'shares', type: 'uint256' }],
        name: 'convertToAssets',
        outputs: [{ type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'convertToAssets',
    args: [parseUnits('1', 18)], // 1 share in wei
  })

  // Read total vault assets for context
  const { data: totalAssets = 0n } = useReadContract({
    address: vaultAddress,
    abi: [
      {
        inputs: [],
        name: 'totalAssets',
        outputs: [{ type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'totalAssets',
  })

  const handleRedemptionSuccess = (requestId: string) => {
    setRefreshTrigger(prev => prev + 1)
  }

  if (!address) {
    return (
      <GlassCard>
        <div className="p-6">
          <div className="flex items-start space-x-3 p-4 bg-blue-500/20 border border-blue-500/30 rounded-lg">
            <Info className="h-5 w-5 text-blue-400 mt-0.5" />
            <p className="text-sm text-blue-300">
              Please connect your wallet to request redemptions from the vault.
            </p>
          </div>
        </div>
      </GlassCard>
    )
  }

  const hasShares = shareBalance > 0n

  return (
    <div className="space-y-6">
      {/* Vault Info */}
      <GlassCard>
        <div className="p-6">
          <h2 className="text-2xl font-bold mb-2">Vault Redemption</h2>
          <p className="text-gray-400 mb-6">
            Request redemption of your vault shares through an EIP-712 signed request
          </p>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <div className="text-sm font-medium">Your Share Balance</div>
              <div className="text-lg font-bold">
                {formatUnits(shareBalance, 18)} shares
              </div>
            </div>
            <div>
              <div className="text-sm font-medium">Current Share Price</div>
              <div className="text-lg font-bold">
                {formatUnits(currentSharePrice, 8)} BTC/share
              </div>
            </div>
            <div>
              <div className="text-sm font-medium">Total Vault Assets</div>
              <div className="text-lg font-bold">
                {formatUnits(totalAssets, 8)} BTC
              </div>
            </div>
          </div>

          {!hasShares && (
            <div className="mt-4 flex items-start space-x-3 p-4 bg-yellow-500/20 border border-yellow-500/30 rounded-lg">
              <AlertTriangle className="h-5 w-5 text-yellow-400 mt-0.5" />
              <p className="text-sm text-yellow-300">
                You don't have any vault shares to redeem. Deposit into the vault first to receive shares.
              </p>
            </div>
          )}
        </div>
      </GlassCard>

      {/* Important Notice */}
      <Alert>
        <Info className="h-4 w-4" />
        <AlertDescription>
          <strong>Important:</strong> Redemption requests are processed manually by vault administrators. 
          Your request will be queued and processed based on vault liquidity and administrative availability. 
          Processing times may vary.
        </AlertDescription>
      </Alert>

      {/* Main Content */}
      <Tabs defaultValue="request" className="w-full">
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="request">Submit Request</TabsTrigger>
          <TabsTrigger value="history">Your Requests</TabsTrigger>
        </TabsList>

        <TabsContent value="request" className="space-y-4">
          {hasShares ? (
            <RedemptionRequestForm
              vaultAddress={vaultAddress}
              deploymentId={deploymentId}
              shareBalance={shareBalance}
              currentSharePrice={currentSharePrice}
              onSuccess={handleRedemptionSuccess}
            />
          ) : (
            <Card>
              <CardContent className="pt-6">
                <div className="text-center py-8">
                  <AlertTriangle className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
                  <h3 className="text-lg font-semibold mb-2">No Shares to Redeem</h3>
                  <p className="text-muted-foreground">
                    You need to have vault shares before you can request redemptions.
                  </p>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="history" className="space-y-4">
          <UserRedemptionRequests
            deploymentId={deploymentId}
            refreshTrigger={refreshTrigger}
          />
        </TabsContent>
      </Tabs>

      {/* Process Information */}
      <Card>
        <CardHeader>
          <CardTitle>How Redemption Works</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex items-start space-x-3">
              <Badge variant="outline" className="mt-1">1</Badge>
              <div>
                <div className="font-medium">Submit Request</div>
                <div className="text-sm text-muted-foreground">
                  Fill out the redemption form and sign an EIP-712 message with your wallet
                </div>
              </div>
            </div>
            
            <div className="flex items-start space-x-3">
              <Badge variant="outline" className="mt-1">2</Badge>
              <div>
                <div className="font-medium">Admin Review</div>
                <div className="text-sm text-muted-foreground">
                  Vault administrators review your request and check vault liquidity
                </div>
              </div>
            </div>
            
            <div className="flex items-start space-x-3">
              <Badge variant="outline" className="mt-1">3</Badge>
              <div>
                <div className="font-medium">Queue Processing</div>
                <div className="text-sm text-muted-foreground">
                  Approved requests are processed in order based on priority and submission time
                </div>
              </div>
            </div>
            
            <div className="flex items-start space-x-3">
              <Badge variant="outline" className="mt-1">4</Badge>
              <div>
                <div className="font-medium">Asset Delivery</div>
                <div className="text-sm text-muted-foreground">
                  Your vault shares are burned and you receive the underlying BTC assets
                </div>
              </div>
            </div>
          </div>
          
          <div className="mt-6 p-4 bg-muted rounded-lg">
            <div className="text-sm text-muted-foreground space-y-1">
              <p><strong>Note:</strong> Signature deadlines protect against stale requests</p>
              <p><strong>Slippage:</strong> Protects you from unfavorable price movements</p>
              <p><strong>Priority:</strong> Emergency requests may receive higher priority</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}