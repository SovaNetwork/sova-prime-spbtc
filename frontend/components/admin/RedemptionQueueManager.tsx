'use client'

import { useState, useEffect } from 'react'
import { formatUnits } from 'viem'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from '@/components/ui/dialog'
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
  XCircle,
  Clock,
  AlertTriangle,
  TrendingUp,
  Users,
  Timer,
  ExternalLink,
  ArrowUp,
  ArrowDown,
} from 'lucide-react'
import {
  redemptionAPI,
  RedemptionRequestResponse,
  RedemptionStatus,
  getStatusColor,
  getStatusDescription,
} from '@/lib/redemption-api'
import { useToast } from '@/hooks/use-toast'

interface RedemptionQueueManagerProps {
  deploymentId: string
}

interface QueueStats {
  totalRequests: number
  pendingRequests: number
  approvedRequests: number
  processingRequests: number
  completedRequests: number
  failedRequests: number
  averageProcessingTime: number | null
  queueLength: number
}

export function RedemptionQueueManager({ deploymentId }: RedemptionQueueManagerProps) {
  const { toast } = useToast()

  // State
  const [requests, setRequests] = useState<RedemptionRequestResponse[]>([])
  const [stats, setStats] = useState<QueueStats | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedStatus, setSelectedStatus] = useState<RedemptionStatus | 'ALL'>('ALL')
  const [processingId, setProcessingId] = useState<string | null>(null)

  // Dialog state
  const [actionDialog, setActionDialog] = useState<{
    type: 'approve' | 'reject' | 'process' | 'setPriority' | null
    request: RedemptionRequestResponse | null
  }>({ type: null, request: null })

  // Form state for dialogs
  const [adminNotes, setAdminNotes] = useState('')
  const [rejectionReason, setRejectionReason] = useState('')
  const [priority, setPriority] = useState('')
  const [txHash, setTxHash] = useState('')
  const [actualAssets, setActualAssets] = useState('')
  const [gasCost, setGasCost] = useState('')

  const fetchData = async () => {
    try {
      setError(null)
      
      // Fetch requests and stats in parallel
      const [requestsResponse, statsResponse] = await Promise.all([
        redemptionAPI.getRedemptionRequests({
          deploymentId,
          status: selectedStatus === 'ALL' ? undefined : [selectedStatus],
          limit: 100,
        }),
        redemptionAPI.getQueueStats(deploymentId),
      ])

      setRequests(requestsResponse.requests)
      setStats(statsResponse)
    } catch (err) {
      console.error('Error fetching redemption data:', err)
      setError(err instanceof Error ? err.message : 'Failed to fetch data')
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
  }, [deploymentId, selectedStatus])

  const handleAction = async (
    type: 'approve' | 'reject' | 'process' | 'setPriority',
    requestId: string
  ) => {
    setProcessingId(requestId)

    try {
      let response: RedemptionRequestResponse

      switch (type) {
        case 'approve':
          response = await redemptionAPI.updateRedemptionStatus({
            id: requestId,
            status: RedemptionStatus.APPROVED,
            adminNotes: adminNotes || undefined,
          })
          toast({
            title: 'Request approved',
            description: 'The redemption request has been approved and added to the queue',
          })
          break

        case 'reject':
          response = await redemptionAPI.updateRedemptionStatus({
            id: requestId,
            status: RedemptionStatus.REJECTED,
            adminNotes: adminNotes || undefined,
            rejectionReason: rejectionReason || 'Rejected by admin',
          })
          toast({
            title: 'Request rejected',
            description: 'The redemption request has been rejected',
          })
          break

        case 'process':
          // First mark as processing
          await redemptionAPI.updateRedemptionStatus({
            id: requestId,
            status: RedemptionStatus.PROCESSING,
          })
          
          // Then mark as completed
          response = await redemptionAPI.markRedemptionProcessed({
            id: requestId,
            txHash,
            actualAssets,
            gasCost: gasCost || '0',
          })
          toast({
            title: 'Request processed',
            description: 'The redemption has been successfully processed',
          })
          break

        case 'setPriority':
          response = await redemptionAPI.updateRedemptionStatus({
            id: requestId,
            status: RedemptionStatus.APPROVED, // Keep approved status
            priority: parseInt(priority) || 0,
          })
          toast({
            title: 'Priority updated',
            description: 'The request priority has been updated',
          })
          break

        default:
          throw new Error('Invalid action type')
      }

      // Reset form and close dialog
      setAdminNotes('')
      setRejectionReason('')
      setPriority('')
      setTxHash('')
      setActualAssets('')
      setGasCost('')
      setActionDialog({ type: null, request: null })

      // Refresh data
      await fetchData()
    } catch (error) {
      console.error(`Error ${type}ing request:`, error)
      toast({
        title: 'Action failed',
        description: error instanceof Error ? error.message : `Failed to ${type} request`,
        variant: 'destructive',
      })
    } finally {
      setProcessingId(null)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString()
  }

  const formatTime = (seconds: number | null) => {
    if (!seconds) return 'N/A'
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    return `${hours}h ${minutes}m`
  }

  const getBlockExplorerUrl = (txHash: string) => {
    return `https://sepolia.basescan.org/tx/${txHash}`
  }

  if (isLoading) {
    return (
      <Card>
        <CardContent className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin mr-2" />
          Loading redemption queue...
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Alert variant="destructive">
        <AlertDescription>
          {error}
          <Button variant="outline" size="sm" onClick={fetchData} className="ml-2">
            <RefreshCw className="h-4 w-4 mr-1" />
            Retry
          </Button>
        </AlertDescription>
      </Alert>
    )
  }

  return (
    <div className="space-y-6">
      {/* Stats Overview */}
      {stats && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <Users className="h-4 w-4 text-muted-foreground" />
                <div>
                  <div className="text-2xl font-bold">{stats.totalRequests}</div>
                  <div className="text-xs text-muted-foreground">Total Requests</div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <Clock className="h-4 w-4 text-yellow-500" />
                <div>
                  <div className="text-2xl font-bold">{stats.queueLength}</div>
                  <div className="text-xs text-muted-foreground">Queue Length</div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <TrendingUp className="h-4 w-4 text-green-500" />
                <div>
                  <div className="text-2xl font-bold">{stats.completedRequests}</div>
                  <div className="text-xs text-muted-foreground">Completed</div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <Timer className="h-4 w-4 text-blue-500" />
                <div>
                  <div className="text-2xl font-bold">
                    {formatTime(stats.averageProcessingTime)}
                  </div>
                  <div className="text-xs text-muted-foreground">Avg Processing</div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Main Queue Management */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Redemption Queue Management</CardTitle>
              <CardDescription>
                Approve, reject, and process redemption requests
              </CardDescription>
            </div>
            <div className="flex items-center space-x-2">
              <Select
                value={selectedStatus}
                onValueChange={(value) => setSelectedStatus(value as RedemptionStatus | 'ALL')}
              >
                <SelectTrigger className="w-40">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ALL">All Status</SelectItem>
                  <SelectItem value={RedemptionStatus.PENDING}>Pending</SelectItem>
                  <SelectItem value={RedemptionStatus.APPROVED}>Approved</SelectItem>
                  <SelectItem value={RedemptionStatus.PROCESSING}>Processing</SelectItem>
                  <SelectItem value={RedemptionStatus.COMPLETED}>Completed</SelectItem>
                  <SelectItem value={RedemptionStatus.FAILED}>Failed</SelectItem>
                  <SelectItem value={RedemptionStatus.REJECTED}>Rejected</SelectItem>
                  <SelectItem value={RedemptionStatus.CANCELLED}>Cancelled</SelectItem>
                </SelectContent>
              </Select>
              <Button variant="outline" size="sm" onClick={fetchData}>
                <RefreshCw className="h-4 w-4 mr-1" />
                Refresh
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {requests.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              No redemption requests found for the selected filter.
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>User</TableHead>
                  <TableHead>Shares</TableHead>
                  <TableHead>Expected BTC</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Queue Position</TableHead>
                  <TableHead>Priority</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {requests.map((request) => (
                  <TableRow key={request.id}>
                    <TableCell className="font-mono text-xs">
                      {request.userAddress.slice(0, 6)}...{request.userAddress.slice(-4)}
                    </TableCell>
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
                      <div className="flex items-center space-x-1">
                        <span>{request.priority}</span>
                        {request.status === RedemptionStatus.APPROVED && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => {
                              setPriority(request.priority.toString())
                              setActionDialog({ type: 'setPriority', request })
                            }}
                          >
                            <ArrowUp className="h-3 w-3" />
                          </Button>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      {formatDate(request.createdAt)}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center space-x-1">
                        {/* Approve Button */}
                        {request.status === RedemptionStatus.PENDING && (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setActionDialog({ type: 'approve', request })}
                            disabled={processingId === request.id}
                          >
                            <CheckCircle className="h-4 w-4" />
                          </Button>
                        )}

                        {/* Reject Button */}
                        {request.status === RedemptionStatus.PENDING && (
                          <Button
                            variant="destructive"
                            size="sm"
                            onClick={() => setActionDialog({ type: 'reject', request })}
                            disabled={processingId === request.id}
                          >
                            <XCircle className="h-4 w-4" />
                          </Button>
                        )}

                        {/* Process Button */}
                        {request.status === RedemptionStatus.APPROVED && (
                          <Button
                            variant="default"
                            size="sm"
                            onClick={() => setActionDialog({ type: 'process', request })}
                            disabled={processingId === request.id}
                          >
                            <TrendingUp className="h-4 w-4" />
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
                              href={getBlockExplorerUrl(request.txHash)}
                              target="_blank"
                              rel="noopener noreferrer"
                            >
                              <ExternalLink className="h-4 w-4" />
                            </a>
                          </Button>
                        )}

                        {processingId === request.id && (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Action Dialogs */}
      <Dialog
        open={actionDialog.type !== null}
        onOpenChange={() => setActionDialog({ type: null, request: null })}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {actionDialog.type === 'approve' && 'Approve Redemption Request'}
              {actionDialog.type === 'reject' && 'Reject Redemption Request'}
              {actionDialog.type === 'process' && 'Process Redemption Request'}
              {actionDialog.type === 'setPriority' && 'Set Priority'}
            </DialogTitle>
            <DialogDescription>
              {actionDialog.request && `Request ID: ${actionDialog.request.id}`}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            {/* Approve Dialog */}
            {actionDialog.type === 'approve' && (
              <>
                <div>
                  <Label htmlFor="approveNotes">Admin Notes (Optional)</Label>
                  <Textarea
                    id="approveNotes"
                    value={adminNotes}
                    onChange={(e) => setAdminNotes(e.target.value)}
                    placeholder="Add any notes about this approval..."
                  />
                </div>
              </>
            )}

            {/* Reject Dialog */}
            {actionDialog.type === 'reject' && (
              <>
                <div>
                  <Label htmlFor="rejectionReason">Rejection Reason *</Label>
                  <Textarea
                    id="rejectionReason"
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    placeholder="Explain why this request is being rejected..."
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="rejectNotes">Admin Notes (Optional)</Label>
                  <Textarea
                    id="rejectNotes"
                    value={adminNotes}
                    onChange={(e) => setAdminNotes(e.target.value)}
                    placeholder="Add any additional notes..."
                  />
                </div>
              </>
            )}

            {/* Process Dialog */}
            {actionDialog.type === 'process' && (
              <>
                <div>
                  <Label htmlFor="txHash">Transaction Hash *</Label>
                  <Input
                    id="txHash"
                    value={txHash}
                    onChange={(e) => setTxHash(e.target.value)}
                    placeholder="0x..."
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="actualAssets">Actual Assets Delivered (BTC) *</Label>
                  <Input
                    id="actualAssets"
                    type="number"
                    step="0.00000001"
                    value={actualAssets}
                    onChange={(e) => setActualAssets(e.target.value)}
                    placeholder="0.12345678"
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="gasCost">Gas Cost (ETH, Optional)</Label>
                  <Input
                    id="gasCost"
                    type="number"
                    step="0.000000001"
                    value={gasCost}
                    onChange={(e) => setGasCost(e.target.value)}
                    placeholder="0.001234567"
                  />
                </div>
              </>
            )}

            {/* Set Priority Dialog */}
            {actionDialog.type === 'setPriority' && (
              <>
                <div>
                  <Label htmlFor="priority">Priority (Higher number = higher priority)</Label>
                  <Input
                    id="priority"
                    type="number"
                    value={priority}
                    onChange={(e) => setPriority(e.target.value)}
                    placeholder="0"
                  />
                </div>
              </>
            )}
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setActionDialog({ type: null, request: null })}
            >
              Cancel
            </Button>
            <Button
              onClick={() => {
                if (actionDialog.type && actionDialog.request) {
                  handleAction(actionDialog.type, actionDialog.request.id)
                }
              }}
              disabled={
                processingId === actionDialog.request?.id ||
                (actionDialog.type === 'reject' && !rejectionReason) ||
                (actionDialog.type === 'process' && (!txHash || !actualAssets))
              }
            >
              {processingId === actionDialog.request?.id ? (
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
              ) : null}
              {actionDialog.type === 'approve' && 'Approve'}
              {actionDialog.type === 'reject' && 'Reject'}
              {actionDialog.type === 'process' && 'Process'}
              {actionDialog.type === 'setPriority' && 'Update Priority'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}