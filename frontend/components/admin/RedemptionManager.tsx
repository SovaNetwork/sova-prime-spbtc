'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { AlertCircle } from 'lucide-react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { RedemptionQueueManager } from './RedemptionQueueManager';
import { RedemptionProcessor } from './RedemptionProcessor';
import { useDeploymentId } from '@/hooks/useDeploymentId';
import { CONTRACTS } from '../../lib/contracts';
import { Loader2 } from 'lucide-react';

export function RedemptionManager() {
  const { address, isConnected } = useAccount();
  const [activeTab, setActiveTab] = useState('queue');
  const { deploymentId, isLoading: isLoadingDeployment } = useDeploymentId();

  const strategyAddress = CONTRACTS.btcVaultStrategy;
  const tokenAddress = CONTRACTS.btcVaultToken;

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <AlertCircle className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-white mb-2">Connect Wallet</h3>
        <p className="text-gray-400">Please connect your wallet to access redemption management</p>
      </div>
    );
  }

  if (isLoadingDeployment || !deploymentId) {
    return (
      <div className="text-center py-12">
        <Loader2 className="w-16 h-16 text-gray-400 mx-auto mb-4 animate-spin" />
        <h3 className="text-xl font-semibold text-white mb-2">Loading...</h3>
        <p className="text-gray-400">Fetching deployment configuration</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="queue">Queue Management</TabsTrigger>
          <TabsTrigger value="process">Batch Processing</TabsTrigger>
        </TabsList>
        
        <TabsContent value="queue" className="mt-6">
          <RedemptionQueueManager deploymentId={deploymentId} />
        </TabsContent>
        
        <TabsContent value="process" className="mt-6">
          <RedemptionProcessor 
            deploymentId={deploymentId}
            strategyAddress={strategyAddress}
            tokenAddress={tokenAddress}
          />
        </TabsContent>
      </Tabs>
    </div>
  );
}