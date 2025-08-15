'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { AlertCircle, RefreshCw, Plus, Trash2, Check, X } from 'lucide-react';
import { useCollaterals, useSyncCollaterals, useAddCollateral, useUpdateCollateral } from '@/hooks/useCollaterals';
import { useDeploymentConfig } from '@/hooks/useDeploymentConfig';
import toast from 'react-hot-toast';

export function CollateralManager() {
  const { chain } = useAccount();
  const chainId = chain?.id || 84532; // Default to Base Sepolia
  
  // For now, we'll pass undefined as deploymentId to get all collaterals for the chain
  const { data: collaterals, isLoading, refetch } = useCollaterals(chainId, undefined);
  const syncCollaterals = useSyncCollaterals();
  const addCollateral = useAddCollateral();
  const updateCollateral = useUpdateCollateral();
  
  const [showAddForm, setShowAddForm] = useState(false);
  const [newCollateral, setNewCollateral] = useState({
    symbol: '',
    name: '',
    address: '',
    decimals: 18,
    logoUri: '',
    coingeckoId: '',
  });

  const handleSync = async () => {
    // For now, sync without a specific deploymentId
    try {
      const result = await syncCollaterals.mutateAsync({
        deploymentId: '', // Will be handled by backend
        chainId,
      });
      
      toast.success(`Synced ${result.collaterals?.length || 0} collaterals from blockchain`);
      refetch();
    } catch (error: any) {
      toast.error(error.message || 'Failed to sync collaterals');
    }
  };

  const handleAdd = async () => {
    // Add collateral without specific deployment

    try {
      await addCollateral.mutateAsync({
        deploymentId: '', // Will be handled by backend
        chainId,
        ...newCollateral,
      });
      
      toast.success(`Added ${newCollateral.symbol} collateral`);
      setShowAddForm(false);
      setNewCollateral({
        symbol: '',
        name: '',
        address: '',
        decimals: 18,
        logoUri: '',
        coingeckoId: '',
      });
      refetch();
    } catch (error: any) {
      toast.error(error.message || 'Failed to add collateral');
    }
  };

  const handleToggleActive = async (collateral: any) => {
    try {
      await updateCollateral.mutateAsync({
        id: collateral.id,
        isActive: !collateral.isActive,
      });
      
      toast.success(`${collateral.isActive ? 'Deactivated' : 'Activated'} ${collateral.symbol}`);
      refetch();
    } catch (error: any) {
      toast.error(error.message || 'Failed to update collateral');
    }
  };

  const handleVerify = async (collateral: any) => {
    try {
      await updateCollateral.mutateAsync({
        id: collateral.id,
        isVerified: !collateral.isVerified,
      });
      
      toast.success(`${collateral.isVerified ? 'Unverified' : 'Verified'} ${collateral.symbol}`);
      refetch();
    } catch (error: any) {
      toast.error(error.message || 'Failed to update collateral');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold">Collateral Management</h3>
        <div className="flex gap-2">
          <button
            onClick={handleSync}
            disabled={syncCollaterals.isPending}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:bg-gray-400 transition-colors"
          >
            <RefreshCw className={`h-4 w-4 ${syncCollaterals.isPending ? 'animate-spin' : ''}`} />
            {syncCollaterals.isPending ? 'Syncing...' : 'Sync from Chain'}
          </button>
          <button
            onClick={() => setShowAddForm(!showAddForm)}
            className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
          >
            <Plus className="h-4 w-4" />
            Add Collateral
          </button>
        </div>
      </div>

      {false && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-yellow-600 mt-0.5" />
          <div>
            <p className="text-yellow-800 font-medium">No deployment configured</p>
            <p className="text-yellow-700 text-sm mt-1">
              Please configure a deployment for {chain?.name || 'this network'} to manage collaterals.
            </p>
          </div>
        </div>
      )}

      {showAddForm && (
        <div className="bg-gray-50 border rounded-lg p-4">
          <h4 className="font-medium mb-3">Add New Collateral</h4>
          <div className="grid grid-cols-2 gap-3">
            <input
              type="text"
              placeholder="Symbol (e.g., WBTC)"
              className="px-3 py-2 border rounded-md"
              value={newCollateral.symbol}
              onChange={(e) => setNewCollateral({ ...newCollateral, symbol: e.target.value })}
            />
            <input
              type="text"
              placeholder="Name (e.g., Wrapped Bitcoin)"
              className="px-3 py-2 border rounded-md"
              value={newCollateral.name}
              onChange={(e) => setNewCollateral({ ...newCollateral, name: e.target.value })}
            />
            <input
              type="text"
              placeholder="Contract Address (0x...)"
              className="px-3 py-2 border rounded-md"
              value={newCollateral.address}
              onChange={(e) => setNewCollateral({ ...newCollateral, address: e.target.value })}
            />
            <input
              type="number"
              placeholder="Decimals (default: 18)"
              className="px-3 py-2 border rounded-md"
              value={newCollateral.decimals}
              onChange={(e) => setNewCollateral({ ...newCollateral, decimals: parseInt(e.target.value) || 18 })}
            />
            <input
              type="text"
              placeholder="Logo URL (optional)"
              className="px-3 py-2 border rounded-md"
              value={newCollateral.logoUri}
              onChange={(e) => setNewCollateral({ ...newCollateral, logoUri: e.target.value })}
            />
            <input
              type="text"
              placeholder="CoinGecko ID (optional)"
              className="px-3 py-2 border rounded-md"
              value={newCollateral.coingeckoId}
              onChange={(e) => setNewCollateral({ ...newCollateral, coingeckoId: e.target.value })}
            />
          </div>
          <div className="flex gap-2 mt-3">
            <button
              onClick={handleAdd}
              disabled={!newCollateral.symbol || !newCollateral.name || !newCollateral.address || addCollateral.isPending}
              className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:bg-gray-400"
            >
              {addCollateral.isPending ? 'Adding...' : 'Add Collateral'}
            </button>
            <button
              onClick={() => setShowAddForm(false)}
              className="px-4 py-2 bg-gray-500 text-white rounded-md hover:bg-gray-600"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      <div className="border rounded-lg overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Token
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Address
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Decimals
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {isLoading ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                  Loading collaterals...
                </td>
              </tr>
            ) : collaterals?.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                  No collaterals found. Click "Sync from Chain" to fetch collaterals.
                </td>
              </tr>
            ) : (
              collaterals?.map((collateral) => (
                <tr key={collateral.id}>
                  <td className="px-4 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      {collateral.logoUri && (
                        <img
                          src={collateral.logoUri}
                          alt={collateral.symbol}
                          className="h-6 w-6 rounded-full mr-2"
                        />
                      )}
                      <div>
                        <div className="text-sm font-medium text-gray-900">
                          {collateral.symbol}
                        </div>
                        <div className="text-xs text-gray-500">
                          {collateral.name}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-4 whitespace-nowrap">
                    <code className="text-xs bg-gray-100 px-2 py-1 rounded">
                      {collateral.address.slice(0, 6)}...{collateral.address.slice(-4)}
                    </code>
                  </td>
                  <td className="px-4 py-4 whitespace-nowrap text-sm text-gray-900">
                    {collateral.decimals}
                  </td>
                  <td className="px-4 py-4 whitespace-nowrap">
                    <div className="flex gap-2">
                      <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                        collateral.isActive 
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-800'
                      }`}>
                        {collateral.isActive ? 'Active' : 'Inactive'}
                      </span>
                      {collateral.isVerified && (
                        <span className="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
                          Verified
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-4 whitespace-nowrap">
                    <div className="flex gap-2">
                      <button
                        onClick={() => handleToggleActive(collateral)}
                        className={`p-1 rounded hover:bg-gray-100 ${
                          collateral.isActive ? 'text-red-600' : 'text-green-600'
                        }`}
                        title={collateral.isActive ? 'Deactivate' : 'Activate'}
                      >
                        {collateral.isActive ? <X className="h-4 w-4" /> : <Check className="h-4 w-4" />}
                      </button>
                      <button
                        onClick={() => handleVerify(collateral)}
                        className={`p-1 rounded hover:bg-gray-100 ${
                          collateral.isVerified ? 'text-gray-600' : 'text-blue-600'
                        }`}
                        title={collateral.isVerified ? 'Unverify' : 'Verify'}
                      >
                        <Check className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {chain && (
        <div className="text-sm text-gray-500">
          <p>Network: {chain.name} (Chain ID: {chainId})</p>
          {true && (
            <p>Chain ID: {chainId}</p>
          )}
        </div>
      )}
    </div>
  );
}