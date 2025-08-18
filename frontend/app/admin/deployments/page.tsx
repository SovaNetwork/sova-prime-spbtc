'use client';

import { useState, useMemo } from 'react';
import { useDeploymentRegistry } from '@/hooks/useDeploymentRegistry';
import { NetworkGrid } from '@/components/admin/NetworkGrid';
import { AddNetworkModal } from '@/components/admin/AddNetworkModal';
import { EditDeploymentModal } from '@/components/admin/EditDeploymentModal';
import { ConfigManager } from '@/components/admin/ConfigManager';
import { NetworkDashboard } from '@/components/admin/NetworkDashboard';
import { DeploymentInfo } from '@/lib/deployments/registry';
import { Plus, Download, Upload, RefreshCw, Activity, Server } from 'lucide-react';
import { toast } from 'react-hot-toast';

export default function DeploymentsPage() {
  const {
    registry,
    isLoading,
    error,
    refresh,
    addDeployment,
    updateDeployment,
    removeDeployment,
  } = useDeploymentRegistry();

  const [showAddModal, setShowAddModal] = useState(false);
  const [editingDeployment, setEditingDeployment] = useState<DeploymentInfo | null>(null);
  const [showConfigManager, setShowConfigManager] = useState(false);
  const [viewMode, setViewMode] = useState<'grid' | 'dashboard'>('grid');

  const deployments = useMemo(() => {
    return registry?.getAllDeployments() || [];
  }, [registry]);

  const activeDeployments = useMemo(() => {
    return deployments.filter(d => d.status === 'active');
  }, [deployments]);

  const handleAddDeployment = (deployment: DeploymentInfo) => {
    addDeployment(deployment.network.chainId, deployment);
    setShowAddModal(false);
    toast.success(`Added deployment for ${deployment.network.name}`);
  };

  const handleUpdateDeployment = (chainId: number, updates: Partial<DeploymentInfo>) => {
    updateDeployment(chainId, updates);
    setEditingDeployment(null);
    toast.success('Deployment updated successfully');
  };

  const handleRemoveDeployment = (chainId: number) => {
    if (confirm('Are you sure you want to remove this deployment?')) {
      removeDeployment(chainId);
      toast.success('Deployment removed');
    }
  };

  const handleRefresh = () => {
    refresh();
    toast.success('Deployments refreshed');
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="glass-card rounded-2xl p-8">
          <div className="animate-pulse flex items-center space-x-3">
            <Server className="w-6 h-6 text-white/60" />
            <span className="text-white/87">Loading deployments...</span>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="glass-card rounded-2xl p-8 max-w-md">
          <div className="text-rose-400 mb-4">Error loading deployments</div>
          <div className="text-white/60 text-sm">{error}</div>
          <button
            onClick={handleRefresh}
            className="mt-4 glass-button rounded-lg px-4 py-2"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">
            Network Deployments
          </h1>
          <p className="text-white/60">
            Manage vault deployments across multiple networks
          </p>
        </div>

        {/* Stats Bar */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <div className="glass-card rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-white/60 text-sm">Total Networks</div>
                <div className="text-2xl font-bold text-white mt-1">
                  {deployments.length}
                </div>
              </div>
              <Server className="w-8 h-8 text-mint-400" />
            </div>
          </div>

          <div className="glass-card rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-white/60 text-sm">Active</div>
                <div className="text-2xl font-bold text-green-400 mt-1">
                  {activeDeployments.length}
                </div>
              </div>
              <Activity className="w-8 h-8 text-green-400" />
            </div>
          </div>

          <div className="glass-card rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-white/60 text-sm">Pending</div>
                <div className="text-2xl font-bold text-yellow-400 mt-1">
                  {deployments.filter(d => d.status === 'pending').length}
                </div>
              </div>
              <Activity className="w-8 h-8 text-yellow-400" />
            </div>
          </div>

          <div className="glass-card rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-white/60 text-sm">Not Deployed</div>
                <div className="text-2xl font-bold text-white/40 mt-1">
                  {deployments.filter(d => d.status === 'not-deployed').length}
                </div>
              </div>
              <Activity className="w-8 h-8 text-white/40" />
            </div>
          </div>
        </div>

        {/* Action Bar */}
        <div className="flex flex-wrap items-center justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <button
              onClick={() => setViewMode('grid')}
              className={`glass-button rounded-lg px-4 py-2 ${
                viewMode === 'grid' ? 'bg-mint-500/20 border-mint-500/50' : ''
              }`}
            >
              Grid View
            </button>
            <button
              onClick={() => setViewMode('dashboard')}
              className={`glass-button rounded-lg px-4 py-2 ${
                viewMode === 'dashboard' ? 'bg-mint-500/20 border-mint-500/50' : ''
              }`}
            >
              Dashboard
            </button>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={handleRefresh}
              className="glass-button rounded-lg p-2"
              title="Refresh"
            >
              <RefreshCw className="w-5 h-5" />
            </button>

            <button
              onClick={() => setShowConfigManager(true)}
              className="glass-button rounded-lg px-4 py-2 flex items-center gap-2"
            >
              <Upload className="w-4 h-4" />
              Import/Export
            </button>

            <button
              onClick={() => setShowAddModal(true)}
              className="bg-gradient-primary text-white rounded-lg px-4 py-2 flex items-center gap-2 font-medium"
            >
              <Plus className="w-4 h-4" />
              Add Network
            </button>
          </div>
        </div>

        {/* Content */}
        {viewMode === 'grid' ? (
          <NetworkGrid
            deployments={deployments}
            onEdit={setEditingDeployment}
            onRemove={handleRemoveDeployment}
          />
        ) : (
          <NetworkDashboard deployments={activeDeployments} />
        )}

        {/* Modals */}
        {showAddModal && (
          <AddNetworkModal
            onAdd={handleAddDeployment}
            onClose={() => setShowAddModal(false)}
            existingChainIds={deployments.map(d => d.network.chainId)}
          />
        )}

        {editingDeployment && (
          <EditDeploymentModal
            deployment={editingDeployment}
            onUpdate={(updates) => handleUpdateDeployment(editingDeployment.network.chainId, updates)}
            onClose={() => setEditingDeployment(null)}
          />
        )}

        {showConfigManager && (
          <ConfigManager
            registry={registry!}
            onClose={() => setShowConfigManager(false)}
          />
        )}
      </div>
    </div>
  );
}