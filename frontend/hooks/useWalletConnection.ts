'use client';

import { useAccount, useConnect, useDisconnect, useChainId, useSwitchChain } from 'wagmi';
import { useEffect, useState, useCallback } from 'react';
import { toast } from 'react-hot-toast';

export type ConnectionState = 'disconnected' | 'connecting' | 'connected' | 'error';

export function useWalletConnection() {
  const { address, isConnected, isConnecting, connector } = useAccount();
  const { connect, connectors, error: connectError, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  
  const [connectionState, setConnectionState] = useState<ConnectionState>('disconnected');
  const [lastConnectedWallet, setLastConnectedWallet] = useState<string | null>(null);

  // Update connection state
  useEffect(() => {
    if (isConnected) {
      setConnectionState('connected');
      if (connector?.name) {
        localStorage.setItem('lastConnectedWallet', connector.name);
        setLastConnectedWallet(connector.name);
      }
    } else if (isConnecting || isPending) {
      setConnectionState('connecting');
    } else if (connectError) {
      setConnectionState('error');
    } else {
      setConnectionState('disconnected');
    }
  }, [isConnected, isConnecting, isPending, connectError, connector]);

  // Load last connected wallet
  useEffect(() => {
    const saved = localStorage.getItem('lastConnectedWallet');
    if (saved) {
      setLastConnectedWallet(saved);
    }
  }, []);

  // Auto-reconnect to last wallet
  const autoReconnect = useCallback(async () => {
    if (!isConnected && lastConnectedWallet && connectors.length > 0) {
      const connector = connectors.find(c => c.name === lastConnectedWallet);
      if (connector) {
        try {
          await connect({ connector });
          toast.success(`Reconnected to ${lastConnectedWallet}`);
        } catch (error) {
          console.error('Auto-reconnect failed:', error);
        }
      }
    }
  }, [isConnected, lastConnectedWallet, connectors, connect]);

  // Handle connection errors
  useEffect(() => {
    if (connectError) {
      const message = connectError.message || 'Failed to connect wallet';
      
      if (message.includes('User rejected')) {
        toast.error('Connection cancelled by user');
      } else if (message.includes('Connector not found')) {
        toast.error('Wallet not found. Please install the wallet extension.');
      } else if (message.includes('Already processing')) {
        // Ignore this error
      } else {
        toast.error(message);
      }
    }
  }, [connectError]);

  // Handle wrong network
  const handleWrongNetwork = useCallback(async (targetChainId: number) => {
    try {
      await switchChain({ chainId: targetChainId });
      toast.success('Network switched successfully');
    } catch (error: any) {
      if (error?.message?.includes('User rejected')) {
        toast.error('Network switch cancelled');
      } else {
        toast.error('Failed to switch network');
      }
    }
  }, [switchChain]);

  // Enhanced disconnect with cleanup
  const enhancedDisconnect = useCallback(() => {
    disconnect();
    localStorage.removeItem('lastConnectedWallet');
    setLastConnectedWallet(null);
    toast.success('Wallet disconnected');
  }, [disconnect]);

  // Connect with error handling
  const connectWallet = useCallback(async (connectorId: string) => {
    const connector = connectors.find(c => c.id === connectorId || c.name.toLowerCase() === connectorId.toLowerCase());
    
    if (!connector) {
      toast.error(`Wallet ${connectorId} not available`);
      return;
    }

    try {
      await connect({ connector });
    } catch (error: any) {
      console.error('Connection error:', error);
      // Error will be handled by the effect above
    }
  }, [connectors, connect]);

  return {
    // State
    address,
    isConnected,
    connectionState,
    chainId,
    connector,
    lastConnectedWallet,
    
    // Actions
    connectWallet,
    disconnect: enhancedDisconnect,
    autoReconnect,
    handleWrongNetwork,
    
    // Utilities
    formatAddress: (addr?: string) => {
      if (!addr) return '';
      return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
    },
  };
}