'use client'

import { useState, useEffect, useCallback } from 'react'
import { useAccount } from 'wagmi'
import { formatUnits } from 'viem'
import { Loader2, ExternalLink, RefreshCw, X } from 'lucide-react'
import { redemptionAPI, RedemptionStatus } from '@/lib/redemption-api'
import toast from 'react-hot-toast'

interface UserRedemptionRequestsProps {
  deploymentId: string
  refreshTrigger?: number
}

export function UserRedemptionRequests({
  deploymentId,
  refreshTrigger = 0,
}: UserRedemptionRequestsProps) {
  const { address } = useAccount()
  const [requests, setRequests] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)

  const fetchRequests = useCallback(async () => {
    if (!address) {
      setIsLoading(false)
      return
    }

    try {
      const data = await redemptionAPI.getUserRequests(address, deploymentId)
      setRequests(data)
    } catch (error) {
      console.error('Failed to fetch redemption requests:', error)
      toast.error('Failed to load your redemption requests')
    } finally {
      setIsLoading(false)
      setIsRefreshing(false)
    }
  }, [address, deploymentId])

  useEffect(() => {
    fetchRequests()
  }, [fetchRequests, refreshTrigger])

  const handleRefresh = () => {
    setIsRefreshing(true)
    fetchRequests()
  }

  const handleCancel = async (requestId: string) => {
    try {
      await redemptionAPI.cancelRequest(requestId)
      toast.success('Request cancelled successfully')
      fetchRequests()
    } catch (error) {
      console.error('Failed to cancel request:', error)
      toast.error('Failed to cancel request')
    }
  }

  const getStatusColor = (status: RedemptionStatus) => {
    switch (status) {
      case RedemptionStatus.PENDING:
        return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30'
      case RedemptionStatus.APPROVED:
        return 'bg-blue-500/20 text-blue-400 border-blue-500/30'
      case RedemptionStatus.PROCESSING:
        return 'bg-mint-500/20 text-mint-400 border-mint-500/30'
      case RedemptionStatus.COMPLETED:
        return 'bg-green-500/20 text-green-400 border-green-500/30'
      case RedemptionStatus.FAILED:
        return 'bg-red-500/20 text-red-400 border-red-500/30'
      case RedemptionStatus.CANCELLED:
        return 'bg-gray-500/20 text-gray-400 border-gray-500/30'
      default:
        return 'bg-gray-500/20 text-gray-400 border-gray-500/30'
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="h-8 w-8 animate-spin text-mint-500" />
      </div>
    )
  }

  if (!requests.length) {
    return (
      <div className="text-center py-8">
        <p className="text-gray-400">No redemption requests found</p>
        <button
          onClick={handleRefresh}
          className="mt-4 px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg transition-all inline-flex items-center space-x-2"
        >
          <RefreshCw className="h-4 w-4" />
          <span>Refresh</span>
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold">Your Redemption Requests</h3>
        <button
          onClick={handleRefresh}
          disabled={isRefreshing}
          className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg transition-all inline-flex items-center space-x-2"
        >
          <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          <span>Refresh</span>
        </button>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b border-white/10">
              <th className="text-left p-2 text-sm font-medium text-gray-400">Amount</th>
              <th className="text-left p-2 text-sm font-medium text-gray-400">Status</th>
              <th className="text-left p-2 text-sm font-medium text-gray-400">Submitted</th>
              <th className="text-left p-2 text-sm font-medium text-gray-400">Actions</th>
            </tr>
          </thead>
          <tbody>
            {requests.map((request) => (
              <tr key={request.id} className="border-b border-white/5">
                <td className="p-2">
                  <div>
                    <div className="font-semibold">
                      {formatUnits(BigInt(request.shareAmount), 18)} shares
                    </div>
                    <div className="text-sm text-gray-400">
                      ≈ {formatUnits(BigInt(request.expectedAssets), 8)} BTC
                    </div>
                  </div>
                </td>
                <td className="p-2">
                  <span className={`px-2 py-1 rounded-full text-xs font-semibold border ${getStatusColor(request.status)}`}>
                    {request.status}
                  </span>
                </td>
                <td className="p-2 text-sm text-gray-400">
                  {new Date(request.createdAt).toLocaleDateString()}
                </td>
                <td className="p-2">
                  <div className="flex space-x-2">
                    {request.status === RedemptionStatus.PENDING && (
                      <button
                        onClick={() => handleCancel(request.id)}
                        className="p-1 hover:bg-white/10 rounded transition-all"
                        title="Cancel request"
                      >
                        <X className="h-4 w-4 text-red-400" />
                      </button>
                    )}
                    {request.txHash && (
                      <a
                        href={`https://basescan.org/tx/${request.txHash}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="p-1 hover:bg-white/10 rounded transition-all"
                        title="View transaction"
                      >
                        <ExternalLink className="h-4 w-4 text-blue-400" />
                      </a>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}