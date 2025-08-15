'use client'

import { useState, useEffect, useMemo } from 'react'
import { formatUnits, parseUnits } from 'viem'
import { useAccount } from 'wagmi'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Loader2,
  RefreshCw,
  CheckCircle,
  AlertTriangle,
  TrendingUp,
  Droplets,
  Package,
  ExternalLink,
  Shield,
} from 'lucide-react'
import {
  redemptionAPI,
  RedemptionRequestResponse,
  RedemptionStatus,
} from '@/lib/redemption-api'
import { useAdminRedemption } from '@/hooks/useAdminRedemption'
import { useToast } from '@/hooks/use-toast'

interface RedemptionProcessorProps {
  deploymentId: string
  strategyAddress: string
  tokenAddress: string
}

export function RedemptionProcessor({
  deploymentId,
  strategyAddress,
  tokenAddress,
}: RedemptionProcessorProps) {
  const { address, isConnected } = useAccount()
  const { toast } = useToast()
  const {
    processBatchRedemption,
    isProcessing,
    currentStep,
    isAdmin,
    checkLiquidity,
    getSharePrice,
  } = useAdminRedemption()

  const [approvedRequests, setApprovedRequests] = useState<RedemptionRequestResponse[]>([])
  const [selectedRequests, setSelectedRequests] = useState<Set<string>>(new Set())
  const [isLoading, setIsLoading] = useState(true)
  const [availableLiquidity, setAvailableLiquidity] = useState<bigint>(0n)
  const [sharePrice, setSharePrice] = useState<bigint>(parseUnits('1', 8))

  // Fetch approved redemption requests
  const fetchApprovedRequests = async () => {
    try {
      setIsLoading(true)
      const response = await redemptionAPI.getRedemptionRequests({
        deploymentId,
        status: [RedemptionStatus.APPROVED],
        limit: 100,
      })
      
      // Sort by priority and queue position
      const sorted = response.requests.sort((a, b) => {
        // Higher priority first
        if (b.priority !== a.priority) {
          return b.priority - a.priority
        }
        // Lower queue position first
        return (a.queuePosition || 0) - (b.queuePosition || 0)
      })
      
      setApprovedRequests(sorted)
    } catch (error) {
      console.error('Error fetching approved requests:', error)
      toast({
        title: 'Failed to fetch requests',
        description: error instanceof Error ? error.message : 'Unknown error',
        variant: 'destructive',
      })
    } finally {
      setIsLoading(false)
    }
  }

  // Fetch liquidity and share price
  const fetchLiquidityInfo = async () => {
    try {
      const [liquidity, price] = await Promise.all([
        checkLiquidity(strategyAddress),
        getSharePrice(tokenAddress),
      ])
      setAvailableLiquidity(liquidity)
      setSharePrice(price)
    } catch (error) {
      console.error('Error fetching liquidity info:', error)
    }
  }

  useEffect(() => {
    fetchApprovedRequests()
    fetchLiquidityInfo()
    
    // Refresh every 30 seconds
    const interval = setInterval(() => {
      fetchApprovedRequests()
      fetchLiquidityInfo()
    }, 30000)
    
    return () => clearInterval(interval)
  }, [deploymentId])

  // Calculate totals for selected requests
  const selectedTotals = useMemo(() => {
    const selected = approvedRequests.filter(req => selectedRequests.has(req.id))
    
    const totalShares = selected.reduce((sum, req) => {
      return sum + BigInt(req.shareAmount)
    }, 0n)
    
    const totalAssets = (totalShares * sharePrice) / parseUnits('1', 18)
    
    return {
      count: selected.length,
      shares: totalShares,
      assets: totalAssets,
      requests: selected,
    }
  }, [selectedRequests, approvedRequests, sharePrice])

  // Toggle selection
  const toggleSelection = (requestId: string) => {
    const newSelection = new Set(selectedRequests)
    if (newSelection.has(requestId)) {
      newSelection.delete(requestId)
    } else {
      newSelection.add(requestId)
    }
    setSelectedRequests(newSelection)
  }

  // Select all/none
  const selectAll = () => {
    if (selectedRequests.size === approvedRequests.length) {
      setSelectedRequests(new Set())
    } else {
      setSelectedRequests(new Set(approvedRequests.map(r => r.id)))
    }
  }

  // Process selected redemptions
  const handleProcessRedemptions = async () => {
    if (selectedTotals.requests.length === 0) {
      toast({
        title: 'No requests selected',
        description: 'Please select redemption requests to process',
        variant: 'destructive',
      })
      return
    }

    await processBatchRedemption({
      requests: selectedTotals.requests,
      strategyAddress,
      tokenAddress,
    })

    // Clear selection and refresh
    setSelectedRequests(new Set())
    await fetchApprovedRequests()
    await fetchLiquidityInfo()
  }

  if (!isConnected) {
    return (
      <Alert>
        <AlertTriangle className="h-4 w-4" />
        <AlertDescription>
          Please connect your wallet to access the redemption processor
        </AlertDescription>
      </Alert>
    )
  }

  if (!isAdmin) {
    return (
      <Alert variant="destructive">
        <Shield className="h-4 w-4" />
        <AlertDescription>
          You do not have permission to process redemptions. Only PROTOCOL_ADMIN role holders can access this feature.
        </AlertDescription>
      </Alert>
    )
  }

  if (isLoading) {
    return (
      <Card>
        <CardContent className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin mr-2" />
          Loading redemption processor...
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Liquidity Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center space-x-2">
              <Droplets className="h-5 w-5 text-blue-500" />
              <div>
                <div className="text-2xl font-bold">
                  {formatUnits(availableLiquidity, 8)} BTC
                </div>
                <div className="text-xs text-muted-foreground">Available Liquidity</div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center space-x-2">
              <Package className="h-5 w-5 text-orange-500" />
              <div>
                <div className="text-2xl font-bold">{approvedRequests.length}</div>
                <div className="text-xs text-muted-foreground">Approved Requests</div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center space-x-2">
              <TrendingUp className="h-5 w-5 text-green-500" />
              <div>
                <div className="text-2xl font-bold">
                  {formatUnits(sharePrice, 8)} BTC
                </div>
                <div className="text-xs text-muted-foreground">Share Price</div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Selected Summary */}
      {selectedTotals.count > 0 && (
        <Alert>
          <AlertDescription className="flex items-center justify-between">
            <span>
              Selected {selectedTotals.count} requests totaling{' '}
              <strong>{formatUnits(selectedTotals.assets, 8)} BTC</strong>
              {selectedTotals.assets > availableLiquidity && (
                <Badge variant="destructive" className="ml-2">
                  Insufficient Liquidity
                </Badge>
              )}
            </span>
            <Button
              onClick={handleProcessRedemptions}
              disabled={
                isProcessing ||
                selectedTotals.assets > availableLiquidity ||
                selectedTotals.count === 0
              }
            >
              {isProcessing ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  {currentStep === 'approving' && 'Approving...'}
                  {currentStep === 'redeeming' && 'Redeeming...'}
                  {currentStep === 'updating' && 'Updating...'}
                </>
              ) : (
                <>
                  <CheckCircle className="h-4 w-4 mr-2" />
                  Process Selected
                </>
              )}
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* Redemption Queue */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Approved Redemption Queue</CardTitle>
              <CardDescription>
                Select requests to process in batch
              </CardDescription>
            </div>
            <div className="flex items-center space-x-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  fetchApprovedRequests()
                  fetchLiquidityInfo()
                }}
              >
                <RefreshCw className="h-4 w-4 mr-1" />
                Refresh
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {approvedRequests.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              No approved redemption requests in the queue
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-12">
                    <input
                      type="checkbox"
                      checked={selectedRequests.size === approvedRequests.length}
                      onChange={selectAll}
                      className="rounded border-zinc-700"
                    />
                  </TableHead>
                  <TableHead>User</TableHead>
                  <TableHead>Shares</TableHead>
                  <TableHead>Expected BTC</TableHead>
                  <TableHead>Priority</TableHead>
                  <TableHead>Queue</TableHead>
                  <TableHead>Created</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {approvedRequests.map((request) => {
                  const shareAmount = BigInt(request.shareAmount)
                  const expectedAssets = (shareAmount * sharePrice) / parseUnits('1', 18)
                  
                  return (
                    <TableRow key={request.id}>
                      <TableCell>
                        <input
                          type="checkbox"
                          checked={selectedRequests.has(request.id)}
                          onChange={() => toggleSelection(request.id)}
                          className="rounded border-zinc-700"
                        />
                      </TableCell>
                      <TableCell className="font-mono text-xs">
                        {request.userAddress.slice(0, 6)}...
                        {request.userAddress.slice(-4)}
                      </TableCell>
                      <TableCell>
                        {formatUnits(shareAmount, 18)}
                      </TableCell>
                      <TableCell>
                        {formatUnits(expectedAssets, 8)}
                      </TableCell>
                      <TableCell>
                        <Badge variant={request.priority > 0 ? 'default' : 'secondary'}>
                          {request.priority}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        #{request.queuePosition || '-'}
                      </TableCell>
                      <TableCell className="text-xs">
                        {new Date(request.createdAt).toLocaleDateString()}
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Processing Status */}
      {isProcessing && (
        <Alert>
          <Loader2 className="h-4 w-4 animate-spin" />
          <AlertDescription>
            {currentStep === 'approving' && 'Step 1/3: Approving token withdrawal from strategy...'}
            {currentStep === 'redeeming' && 'Step 2/3: Processing batch redemption...'}
            {currentStep === 'updating' && 'Step 3/3: Updating database records...'}
          </AlertDescription>
        </Alert>
      )}
    </div>
  )
}