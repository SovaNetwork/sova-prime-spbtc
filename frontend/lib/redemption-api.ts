import { SignedRedemptionRequest } from './eip712'
import { serializeBigInt } from './utils'

// Types for API communication
export interface RedemptionRequestResponse {
  id: string
  deploymentId: string
  userAddress: string
  shareAmount: string
  expectedAssets: string
  minAssetsOut: string
  signature: string
  nonce: string
  deadline: string
  status: RedemptionStatus
  priority: number
  queuePosition: number | null
  processedAt: string | null
  txHash: string | null
  actualAssets: string | null
  gasCost: string | null
  adminNotes: string | null
  rejectionReason: string | null
  createdAt: string
  updatedAt: string
}

export enum RedemptionStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  PROCESSING = 'PROCESSING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
  CANCELLED = 'CANCELLED',
  REJECTED = 'REJECTED',
  EXPIRED = 'EXPIRED',
}

export interface CreateRedemptionRequestParams {
  deploymentId: string
  expectedAssets: string
  signedRequest: SignedRedemptionRequest
}

export interface UpdateRedemptionStatusParams {
  id: string
  status: RedemptionStatus
  adminNotes?: string
  rejectionReason?: string
  priority?: number
}

export interface ProcessRedemptionParams {
  id: string
  txHash: string
  actualAssets: string
  gasCost: string
}

export interface RedemptionQueueFilters {
  status?: RedemptionStatus[]
  userAddress?: string
  deploymentId?: string
  page?: number
  limit?: number
}

// API Client for redemption requests
export class RedemptionAPI {
  private baseUrl: string

  constructor(baseUrl = '/api') {
    this.baseUrl = baseUrl
  }

  // Submit a new redemption request
  async submitRedemptionRequest(params: CreateRedemptionRequestParams): Promise<RedemptionRequestResponse> {
    const response = await fetch(`${this.baseUrl}/redemptions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(serializeBigInt(params)),
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Failed to submit redemption request: ${error}`)
    }

    return response.json()
  }

  // Get redemption requests (with filtering and pagination)
  async getRedemptionRequests(filters?: RedemptionQueueFilters): Promise<{
    requests: RedemptionRequestResponse[]
    totalCount: number
    page: number
    limit: number
  }> {
    const params = new URLSearchParams()
    
    if (filters?.status?.length) {
      filters.status.forEach(status => params.append('status', status))
    }
    if (filters?.userAddress) {
      params.append('userAddress', filters.userAddress)
    }
    if (filters?.deploymentId) {
      params.append('deploymentId', filters.deploymentId)
    }
    if (filters?.page) {
      params.append('page', filters.page.toString())
    }
    if (filters?.limit) {
      params.append('limit', filters.limit.toString())
    }

    const response = await fetch(`${this.baseUrl}/redemptions?${params}`)
    
    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Failed to fetch redemption requests: ${error}`)
    }

    return response.json()
  }

  // Get user's redemption requests
  async getUserRequests(userAddress: string, deploymentId?: string): Promise<RedemptionRequestResponse[]> {
    const filters: RedemptionQueueFilters = {
      userAddress,
      deploymentId,
    }
    
    const result = await this.getRedemptionRequests(filters)
    return result.requests
  }

  // Get a specific redemption request
  async getRedemptionRequest(id: string): Promise<RedemptionRequestResponse> {
    const response = await fetch(`${this.baseUrl}/redemptions/${id}`)
    
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error('Redemption request not found')
      }
      const error = await response.text()
      throw new Error(`Failed to fetch redemption request: ${error}`)
    }

    return response.json()
  }

  // Update redemption request status (admin only)
  async updateRedemptionStatus(params: UpdateRedemptionStatusParams): Promise<RedemptionRequestResponse> {
    const response = await fetch(`${this.baseUrl}/redemptions/${params.id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(serializeBigInt({
        status: params.status,
        adminNotes: params.adminNotes,
        rejectionReason: params.rejectionReason,
        priority: params.priority,
      })),
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Failed to update redemption request: ${error}`)
    }

    return response.json()
  }

  // Mark redemption as processed (admin only)
  async markRedemptionProcessed(params: ProcessRedemptionParams): Promise<RedemptionRequestResponse> {
    const response = await fetch(`${this.baseUrl}/redemptions/${params.id}/process`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(serializeBigInt({
        txHash: params.txHash,
        actualAssets: params.actualAssets,
        gasCost: params.gasCost,
      })),
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Failed to mark redemption as processed: ${error}`)
    }

    return response.json()
  }

  // Cancel redemption request (user or admin)
  async cancelRedemptionRequest(id: string, reason?: string): Promise<RedemptionRequestResponse> {
    const response = await fetch(`${this.baseUrl}/redemptions/${id}/cancel`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(serializeBigInt({ reason })),
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Failed to cancel redemption request: ${error}`)
    }

    return response.json()
  }

  // Get user's redemption requests
  async getUserRedemptions(userAddress: string, filters?: Omit<RedemptionQueueFilters, 'userAddress'>): Promise<{
    requests: RedemptionRequestResponse[]
    totalCount: number
    page: number
    limit: number
  }> {
    return this.getRedemptionRequests({
      ...filters,
      userAddress,
    })
  }

  // Alias for cancelRedemptionRequest for backwards compatibility
  async cancelRequest(id: string, reason?: string): Promise<RedemptionRequestResponse> {
    return this.cancelRedemptionRequest(id, reason)
  }

  // Get queue statistics
  async getQueueStats(deploymentId?: string): Promise<{
    totalRequests: number
    pendingRequests: number
    approvedRequests: number
    processingRequests: number
    completedRequests: number
    failedRequests: number
    averageProcessingTime: number | null
    queueLength: number
  }> {
    const params = new URLSearchParams()
    if (deploymentId) {
      params.append('deploymentId', deploymentId)
    }

    const response = await fetch(`${this.baseUrl}/redemptions/stats?${params}`)
    
    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Failed to fetch queue stats: ${error}`)
    }

    return response.json()
  }
}

// Create a default instance
export const redemptionAPI = new RedemptionAPI()

// Status display helpers
export function getStatusColor(status: RedemptionStatus): string {
  switch (status) {
    case RedemptionStatus.PENDING:
      return 'text-yellow-600 bg-yellow-100'
    case RedemptionStatus.APPROVED:
      return 'text-blue-600 bg-blue-100'
    case RedemptionStatus.PROCESSING:
      return 'text-mint-600 bg-purple-100'
    case RedemptionStatus.COMPLETED:
      return 'text-green-600 bg-green-100'
    case RedemptionStatus.FAILED:
      return 'text-red-600 bg-red-100'
    case RedemptionStatus.CANCELLED:
      return 'text-gray-600 bg-gray-100'
    case RedemptionStatus.REJECTED:
      return 'text-red-600 bg-red-100'
    case RedemptionStatus.EXPIRED:
      return 'text-orange-600 bg-orange-100'
    default:
      return 'text-gray-600 bg-gray-100'
  }
}

export function getStatusDescription(status: RedemptionStatus): string {
  switch (status) {
    case RedemptionStatus.PENDING:
      return 'Waiting for admin approval'
    case RedemptionStatus.APPROVED:
      return 'Approved and ready for processing'
    case RedemptionStatus.PROCESSING:
      return 'Currently being processed on-chain'
    case RedemptionStatus.COMPLETED:
      return 'Successfully completed'
    case RedemptionStatus.FAILED:
      return 'Processing failed - can be retried'
    case RedemptionStatus.CANCELLED:
      return 'Cancelled by user or admin'
    case RedemptionStatus.REJECTED:
      return 'Rejected by admin'
    case RedemptionStatus.EXPIRED:
      return 'Signature has expired'
    default:
      return 'Unknown status'
  }
}