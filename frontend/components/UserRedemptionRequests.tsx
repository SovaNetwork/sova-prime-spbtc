'use client'

import { useState, useEffect } from 'react'
import { useAccount } from 'wagmi'
import { formatUnits } from 'viem'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Loader2, ExternalLink, RefreshCw, X } from 'lucide-react'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import {
  redemptionAPI,
  RedemptionRequestResponse,
  RedemptionStatus,
  getStatusColor,
  getStatusDescription,
} from '@/lib/redemption-api'
import { useToast } from '@/hooks/use-toast'

interface UserRedemptionRequestsProps {
  deploymentId: string
  refreshTrigger?: number
}

export function UserRedemptionRequests({
  deploymentId,
  refreshTrigger = 0,
}: UserRedemptionRequestsProps) {
  const { address } = useAccount()
  const { toast } = useToast()

  const [requests, setRequests] = useState<RedemptionRequestResponse[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [cancellingId, setCancellingId] = useState<string | null>(null)

  const fetchRequests = async () => {
    if (!address) {
      setRequests([])
      setIsLoading(false)
      return
    }

    try {
      setError(null)
      const response = await redemptionAPI.getUserRedemptions(address, {
        deploymentId,
        limit: 50,
      })
      setRequests(response.requests)
    } catch (err) {
      console.error('Error fetching user redemption requests:', err)
      setError(err instanceof Error ? err.message : 'Failed to fetch requests')
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchRequests()
  }, [address, deploymentId, refreshTrigger])

  const handleCancelRequest = async (requestId: string) => {
    setCancellingId(requestId)
    
    try {
      await redemptionAPI.cancelRedemptionRequest(requestId, 'Cancelled by user')
      
      toast({
        title: 'Request cancelled',
        description: 'Your redemption request has been cancelled successfully',
      })
      
      // Refresh the list
      await fetchRequests()
    } catch (error) {
      console.error('Error cancelling request:', error)
      toast({
        title: 'Cancellation failed',
        description: error instanceof Error ? error.message : 'Failed to cancel request',
        variant: 'destructive',
      })
    } finally {
      setCancellingId(null)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString()
  }

  const getBlockExplorerUrl = (txHash: string, chainId: number) => {
    // Base Sepolia block explorer
    if (chainId === 84532) {
      return `https://sepolia.basescan.org/tx/${txHash}`
    }
    return `https://etherscan.io/tx/${txHash}`
  }

  const canCancel = (status: RedemptionStatus) => {
    return [
      RedemptionStatus.PENDING,
      RedemptionStatus.APPROVED,
      RedemptionStatus.FAILED,
    ].includes(status)
  }

  if (!address) {
    return (
      <Alert>
        <AlertDescription>
          Please connect your wallet to view your redemption requests
        </AlertDescription>
      </Alert>
    )
  }

  if (isLoading) {
    return (
      <Card>
        <CardContent className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin mr-2" />
          Loading your redemption requests...
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Alert variant="destructive">
        <AlertDescription>
          {error}
          <Button
            variant="outline"
            size="sm"
            onClick={fetchRequests}
            className="ml-2"
          >
            <RefreshCw className="h-4 w-4 mr-1" />
            Retry
          </Button>
        </AlertDescription>
      </Alert>
    )
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div>
            <CardTitle>Your Redemption Requests</CardTitle>
            <CardDescription>
              Track the status of your submitted redemption requests
            </CardDescription>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={fetchRequests}
            disabled={isLoading}
          >
            <RefreshCw className={`h-4 w-4 mr-1 ${isLoading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {requests.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            No redemption requests found. Submit your first request above.
          </div>
        ) : (
          <div className="space-y-4">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Shares</TableHead>
                  <TableHead>Expected BTC</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Queue Position</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {requests.map((request) => (
                  <TableRow key={request.id}>
                    <TableCell>
                      {formatUnits(BigInt(request.shareAmount), 18)}
                    </TableCell>
                    <TableCell>
                      {formatUnits(BigInt(request.expectedAssets), 8)} BTC
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant="secondary"
                        className={getStatusColor(request.status as RedemptionStatus)}
                      >
                        {request.status}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {request.queuePosition ? `#${request.queuePosition}` : '-'}
                    </TableCell>
                    <TableCell>
                      {formatDate(request.createdAt)}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center space-x-2">
                        {/* View Details */}
                        <Dialog>
                          <DialogTrigger>
                            Details
                          </DialogTrigger>
                          <DialogContent className="max-w-2xl">
                            <DialogHeader>
                              <DialogTitle>Redemption Request Details</DialogTitle>
                              <DialogDescription>
                                Request ID: {request.id}
                              </DialogDescription>
                            </DialogHeader>
                            <div className="space-y-4">
                              <div className="grid grid-cols-2 gap-4">
                                <div>
                                  <div className="text-sm font-medium">Shares to Redeem</div>
                                  <div className="text-sm text-muted-foreground">
                                    {formatUnits(BigInt(request.shareAmount), 18)}
                                  </div>
                                </div>
                                <div>
                                  <div className="text-sm font-medium">Expected Assets</div>
                                  <div className="text-sm text-muted-foreground">
                                    {formatUnits(BigInt(request.expectedAssets), 8)} BTC
                                  </div>
                                </div>
                                <div>
                                  <div className="text-sm font-medium">Minimum Assets</div>
                                  <div className="text-sm text-muted-foreground">
                                    {formatUnits(BigInt(request.minAssetsOut), 8)} BTC
                                  </div>
                                </div>
                                <div>
                                  <div className="text-sm font-medium">Status</div>
                                  <Badge
                                    variant="secondary"
                                    className={getStatusColor(request.status as RedemptionStatus)}
                                  >
                                    {request.status}
                                  </Badge>
                                </div>
                                <div>
                                  <div className="text-sm font-medium">Created</div>
                                  <div className="text-sm text-muted-foreground">
                                    {formatDate(request.createdAt)}
                                  </div>
                                </div>
                                <div>
                                  <div className="text-sm font-medium">Deadline</div>
                                  <div className="text-sm text-muted-foreground">
                                    {formatDate(request.deadline)}
                                  </div>
                                </div>
                              </div>

                              {request.actualAssets && (
                                <div>
                                  <div className="text-sm font-medium">Actual Assets Received</div>
                                  <div className="text-sm text-muted-foreground">
                                    {formatUnits(BigInt(request.actualAssets), 8)} BTC
                                  </div>
                                </div>
                              )}

                              {request.txHash && (
                                <div>
                                  <div className="text-sm font-medium">Transaction</div>
                                  <a
                                    href={getBlockExplorerUrl(request.txHash, 84532)}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-sm text-blue-600 hover:underline flex items-center"
                                  >
                                    {request.txHash}
                                    <ExternalLink className="h-3 w-3 ml-1" />
                                  </a>
                                </div>
                              )}

                              {request.rejectionReason && (
                                <div>
                                  <div className="text-sm font-medium">Rejection Reason</div>
                                  <div className="text-sm text-muted-foreground">
                                    {request.rejectionReason}
                                  </div>
                                </div>
                              )}

                              {request.adminNotes && (
                                <div>
                                  <div className="text-sm font-medium">Admin Notes</div>
                                  <div className="text-sm text-muted-foreground">
                                    {request.adminNotes}
                                  </div>
                                </div>
                              )}

                              <div className="text-xs text-muted-foreground">
                                {getStatusDescription(request.status as RedemptionStatus)}
                              </div>
                            </div>
                          </DialogContent>
                        </Dialog>

                        {/* Cancel Button */}
                        {canCancel(request.status as RedemptionStatus) && (
                          <Button
                            variant="destructive"
                            size="sm"
                            onClick={() => handleCancelRequest(request.id)}
                            disabled={cancellingId === request.id}
                          >
                            {cancellingId === request.id ? (
                              <Loader2 className="h-4 w-4 animate-spin" />
                            ) : (
                              <X className="h-4 w-4" />
                            )}
                          </Button>
                        )}

                        {/* View Transaction */}
                        {request.txHash && (
                          <Button
                            variant="outline"
                            size="sm"
                            asChild
                          >
                            <a
                              href={getBlockExplorerUrl(request.txHash, 84532)}
                              target="_blank"
                              rel="noopener noreferrer"
                            >
                              <ExternalLink className="h-4 w-4" />
                            </a>
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </CardContent>
    </Card>
  )
}