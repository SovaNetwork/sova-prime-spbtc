'use client';

import { useState } from 'react';
import { useAccount, useBalance, useDisconnect, useEnsName, useEnsAvatar } from 'wagmi';
import { formatEther } from 'viem';
import { Wallet, Copy, LogOut, ChevronDown, User, Activity } from 'lucide-react';
import { toast } from 'react-hot-toast';
import { useWalletDetection, walletInfo } from '@/hooks/useWalletDetection';

export function WalletButton() {
  const { address, isConnected, connector } = useAccount();
  const { disconnect } = useDisconnect();
  const { data: balance } = useBalance({ address });
  const { data: ensName } = useEnsName({ address });
  const { data: ensAvatar } = useEnsAvatar({ name: ensName ?? undefined });
  const { detectedWallets } = useWalletDetection();
  const [isOpen, setIsOpen] = useState(false);

  if (!isConnected || !address) {
    return null;
  }

  const copyAddress = () => {
    navigator.clipboard.writeText(address);
    toast.success('Address copied to clipboard');
    setIsOpen(false);
  };

  const handleDisconnect = () => {
    disconnect();
    setIsOpen(false);
  };

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  // Get wallet icon based on connector
  const getWalletIcon = () => {
    const connectorName = connector?.name.toLowerCase() || '';
    
    // Find matching wallet info
    for (const [key, info] of Object.entries(walletInfo)) {
      if (connectorName.includes(key) || connectorName.includes(info.name.toLowerCase())) {
        return info.icon;
      }
    }
    
    return '🔗'; // Default icon
  };

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="glass-button rounded-xl px-4 py-2 flex items-center space-x-2 transition-all duration-300"
      >
        {ensAvatar ? (
          <img src={ensAvatar} alt="ENS Avatar" className="w-5 h-5 rounded-full" />
        ) : (
          <span className="text-lg">{getWalletIcon()}</span>
        )}
        <span className="font-medium">
          {ensName || formatAddress(address)}
        </span>
        <ChevronDown className={`w-4 h-4 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {isOpen && (
        <>
          {/* Backdrop */}
          <div 
            className="fixed inset-0 z-40" 
            onClick={() => setIsOpen(false)}
          />
          
          {/* Dropdown */}
          <div className="absolute right-0 mt-2 w-72 z-50">
            <div className="glass-card rounded-2xl overflow-hidden">
              {/* Account Info */}
              <div className="p-4 border-b border-white/10">
                <div className="flex items-center space-x-3">
                  {ensAvatar ? (
                    <img src={ensAvatar} alt="ENS Avatar" className="w-10 h-10 rounded-full" />
                  ) : (
                    <div className="w-10 h-10 bg-gradient-primary rounded-full flex items-center justify-center">
                      <User className="w-5 h-5 text-white" />
                    </div>
                  )}
                  <div className="flex-1">
                    <div className="text-white font-medium">
                      {ensName || formatAddress(address)}
                    </div>
                    <div className="text-white/60 text-sm flex items-center space-x-1">
                      <span>{getWalletIcon()}</span>
                      <span>{connector?.name}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Balance */}
              {balance && (
                <div className="px-4 py-3 border-b border-white/10">
                  <div className="flex items-center justify-between">
                    <span className="text-white/60 text-sm">Balance</span>
                    <span className="text-white font-medium">
                      {parseFloat(formatEther(balance.value)).toFixed(4)} {balance.symbol}
                    </span>
                  </div>
                </div>
              )}

              {/* Actions */}
              <div className="p-2">
                <button
                  onClick={copyAddress}
                  className="w-full flex items-center space-x-3 px-3 py-2 rounded-lg hover:bg-white/5 transition-colors text-left"
                >
                  <Copy className="w-4 h-4 text-white/60" />
                  <span className="text-white/87">Copy Address</span>
                </button>
                
                <button
                  onClick={() => {
                    window.open(`https://basescan.org/address/${address}`, '_blank');
                    setIsOpen(false);
                  }}
                  className="w-full flex items-center space-x-3 px-3 py-2 rounded-lg hover:bg-white/5 transition-colors text-left"
                >
                  <Activity className="w-4 h-4 text-white/60" />
                  <span className="text-white/87">View on Explorer</span>
                </button>
                
                <button
                  onClick={handleDisconnect}
                  className="w-full flex items-center space-x-3 px-3 py-2 rounded-lg hover:bg-white/5 transition-colors text-left text-rose-400"
                >
                  <LogOut className="w-4 h-4" />
                  <span>Disconnect</span>
                </button>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}