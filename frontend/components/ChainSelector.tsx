'use client';

import { useState, useEffect } from 'react';
import { useChainId, useSwitchChain } from 'wagmi';
import { ChevronDown, Globe, CheckCircle, AlertCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

// Supported networks configuration
const SUPPORTED_NETWORKS = [
  { id: 1, name: 'Ethereum', icon: '🔷', color: 'from-blue-500 to-blue-600' },
  { id: 8453, name: 'Base', icon: '🔵', color: 'from-blue-400 to-blue-500' },
  { id: 42161, name: 'Arbitrum', icon: '🔷', color: 'from-blue-600 to-indigo-600' },
  { id: 10, name: 'Optimism', icon: '🔴', color: 'from-red-500 to-red-600' },
  { id: 84532, name: 'Base Sepolia', icon: '🔵', color: 'from-gray-500 to-gray-600' },
  { id: 11155111, name: 'Sepolia', icon: '🔷', color: 'from-gray-600 to-gray-700' },
];

interface ChainSelectorProps {
  onChainSelect?: (chainId: number) => void;
  showAll?: boolean;
  className?: string;
}

export function ChainSelector({ onChainSelect, showAll = false, className }: ChainSelectorProps) {
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const [isOpen, setIsOpen] = useState(false);
  const [selectedChain, setSelectedChain] = useState<number | null>(null);
  const [deployedChains, setDeployedChains] = useState<number[]>([]);

  // Fetch deployed chains from API
  useEffect(() => {
    fetch('/api/deployments')
      .then(res => res.json())
      .then(data => {
        const chains = data.map((d: any) => d.chainId);
        setDeployedChains(chains);
      })
      .catch(console.error);
  }, []);

  const handleChainSelect = (chainId: number) => {
    if (showAll) {
      // Just select for filtering, don't switch network
      setSelectedChain(chainId);
      onChainSelect?.(chainId);
    } else {
      // Switch the actual network
      switchChain?.({ chainId });
    }
    setIsOpen(false);
  };

  const currentNetwork = SUPPORTED_NETWORKS.find(n => n.id === (selectedChain || chainId));
  const availableNetworks = showAll 
    ? SUPPORTED_NETWORKS 
    : SUPPORTED_NETWORKS.filter(n => deployedChains.includes(n.id));

  return (
    <div className={cn("relative", className)}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className={cn(
          "flex items-center gap-2 px-4 py-2 rounded-xl transition-all",
          "bg-white/5 hover:bg-white/10 backdrop-blur-xl",
          "border border-white/10 hover:border-white/20",
          "text-white"
        )}
      >
        {currentNetwork ? (
          <>
            <span className="text-lg">{currentNetwork.icon}</span>
            <span className="font-medium">{currentNetwork.name}</span>
          </>
        ) : (
          <>
            <Globe className="w-4 h-4" />
            <span>Select Network</span>
          </>
        )}
        <ChevronDown className={cn(
          "w-4 h-4 transition-transform",
          isOpen && "rotate-180"
        )} />
      </button>

      {isOpen && (
        <>
          <div 
            className="fixed inset-0 z-40" 
            onClick={() => setIsOpen(false)}
          />
          <div className={cn(
            "absolute top-full mt-2 right-0 z-50",
            "w-64 p-2 rounded-xl",
            "bg-slate-900/95 backdrop-blur-xl",
            "border border-white/10",
            "shadow-2xl shadow-black/50"
          )}>
            <div className="p-2 border-b border-white/10 mb-2">
              <p className="text-xs text-white/60 uppercase tracking-wider">
                {showAll ? 'Filter by Network' : 'Switch Network'}
              </p>
            </div>

            {availableNetworks.length === 0 ? (
              <div className="p-4 text-center text-white/60">
                <AlertCircle className="w-8 h-8 mx-auto mb-2 text-yellow-500" />
                <p className="text-sm">No deployed networks found</p>
              </div>
            ) : (
              <div className="space-y-1">
                {availableNetworks.map((network) => {
                  const isActive = network.id === (selectedChain || chainId);
                  const isDeployed = deployedChains.includes(network.id);
                  
                  return (
                    <button
                      key={network.id}
                      onClick={() => handleChainSelect(network.id)}
                      disabled={!showAll && !isDeployed}
                      className={cn(
                        "w-full flex items-center justify-between gap-2 px-3 py-2 rounded-lg",
                        "transition-all duration-200",
                        isActive
                          ? "bg-gradient-to-r " + network.color + " text-white"
                          : "hover:bg-white/10 text-white/80 hover:text-white",
                        !isDeployed && !showAll && "opacity-50 cursor-not-allowed"
                      )}
                    >
                      <div className="flex items-center gap-2">
                        <span className="text-lg">{network.icon}</span>
                        <span className="font-medium">{network.name}</span>
                      </div>
                      {isActive && (
                        <CheckCircle className="w-4 h-4" />
                      )}
                      {!isDeployed && !showAll && (
                        <span className="text-xs text-white/60">Not deployed</span>
                      )}
                    </button>
                  );
                })}
              </div>
            )}

            {showAll && (
              <div className="mt-2 pt-2 border-t border-white/10">
                <button
                  onClick={() => {
                    setSelectedChain(null);
                    onChainSelect?.(0);
                    setIsOpen(false);
                  }}
                  className="w-full px-3 py-2 text-sm text-white/60 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
                >
                  Show All Networks
                </button>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}