'use client';

import { useState, useEffect } from 'react';
import { useAccount, useChainId, useSwitchChain } from 'wagmi';
import { ChevronDown, AlertCircle, Check } from 'lucide-react';
import { NETWORKS, getNetworkById, isNetworkSupported } from '@/lib/networks';
import { cn } from '@/lib/utils';

export function NetworkSwitcher() {
  const [isOpen, setIsOpen] = useState(false);
  const chainId = useChainId();
  const { isConnected } = useAccount();
  const { switchChain, isPending } = useSwitchChain();
  
  const currentNetwork = getNetworkById(chainId);
  const isSupported = isNetworkSupported(chainId);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('.network-switcher')) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  if (!isConnected) {
    return null;
  }

  const handleNetworkSwitch = async (networkId: number) => {
    if (networkId === chainId) {
      setIsOpen(false);
      return;
    }

    try {
      await switchChain({ chainId: networkId });
      setIsOpen(false);
    } catch (error) {
      console.error('Failed to switch network:', error);
    }
  };

  return (
    <div className="network-switcher relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        disabled={isPending}
        className={cn(
          'flex items-center gap-2 px-4 py-2 rounded-xl transition-all duration-200',
          'bg-white/5 backdrop-blur-xl border',
          isSupported
            ? 'border-white/10 hover:bg-white/10'
            : 'border-orange-500/50 bg-orange-500/10',
          isPending && 'opacity-50 cursor-not-allowed'
        )}
      >
        {isSupported ? (
          <>
            <div className={cn('w-2 h-2 rounded-full', currentNetwork?.color || 'bg-gray-500')} />
            <span className="text-sm font-medium text-white">
              {currentNetwork?.displayName || 'Unknown Network'}
            </span>
          </>
        ) : (
          <>
            <AlertCircle className="w-4 h-4 text-orange-500" />
            <span className="text-sm font-medium text-orange-500">Unsupported Network</span>
          </>
        )}
        <ChevronDown
          className={cn(
            'w-4 h-4 text-white/60 transition-transform duration-200',
            isOpen && 'rotate-180'
          )}
        />
      </button>

      {isOpen && (
        <div className="absolute top-full right-0 mt-2 w-64 rounded-xl overflow-hidden z-50">
          <div className="bg-slate-900/95 backdrop-blur-xl border border-white/10 rounded-xl shadow-xl">
            <div className="p-2">
              <div className="text-xs font-medium text-white/40 px-3 py-2 uppercase tracking-wider">
                Select Network
              </div>
              {NETWORKS.map((network) => {
                const isActive = network.id === chainId;
                const isMainnet = network.id !== 84532; // Not Base Sepolia
                const isDisabled = isMainnet && network.contracts.btcVaultStrategy === '0x0000000000000000000000000000000000000000';

                return (
                  <button
                    key={network.id}
                    onClick={() => !isDisabled && handleNetworkSwitch(network.id)}
                    disabled={isDisabled || isPending}
                    className={cn(
                      'w-full flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200',
                      'hover:bg-white/5',
                      isActive && 'bg-white/10',
                      isDisabled && 'opacity-40 cursor-not-allowed'
                    )}
                  >
                    <div className={cn('w-2 h-2 rounded-full', network.color)} />
                    <div className="flex-1 text-left">
                      <div className="text-sm font-medium text-white">
                        {network.displayName}
                      </div>
                      {isDisabled && (
                        <div className="text-xs text-white/40">Coming Soon</div>
                      )}
                    </div>
                    {isActive && (
                      <Check className="w-4 h-4 text-green-400" />
                    )}
                  </button>
                );
              })}
            </div>
            {!isSupported && (
              <div className="p-3 border-t border-white/10">
                <div className="flex items-start gap-2">
                  <AlertCircle className="w-4 h-4 text-orange-500 mt-0.5" />
                  <div className="flex-1">
                    <div className="text-xs font-medium text-orange-500">
                      Unsupported Network
                    </div>
                    <div className="text-xs text-white/60 mt-1">
                      Please switch to a supported network to use the vault.
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}