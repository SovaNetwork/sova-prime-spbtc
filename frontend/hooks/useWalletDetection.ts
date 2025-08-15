'use client';

import { useEffect, useState } from 'react';

export interface DetectedWallet {
  name: string;
  icon: string;
  installed: boolean;
  connectorId?: string;
}

// Define wallet detection logic
const walletDetectors = {
  metamask: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isMetaMask);
  },
  rabby: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isRabby);
  },
  phantom: () => {
    if (typeof window === 'undefined') return false;
    return !!(window as any).phantom?.ethereum;
  },
  okx: () => {
    if (typeof window === 'undefined') return false;
    return !!(window as any).okxwallet;
  },
  zerion: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isZerion);
  },
  trust: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && (ethereum.isTrust || ethereum.isTrustWallet));
  },
  brave: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isBraveWallet);
  },
  coinbase: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && (ethereum.isCoinbaseWallet || ethereum.selectedProvider?.isCoinbaseWallet));
  },
  rainbow: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isRainbow);
  },
  frame: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isFrame);
  },
  taho: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isTaho);
  },
  safe: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isSafe);
  },
  argent: () => {
    if (typeof window === 'undefined') return false;
    const ethereum = (window as any).ethereum;
    return !!(ethereum && ethereum.isArgent);
  },
};

export const walletInfo = {
  metamask: { name: 'MetaMask', icon: '🦊', priority: 1 },
  rabby: { name: 'Rabby', icon: '🐰', priority: 2 },
  rainbow: { name: 'Rainbow', icon: '🌈', priority: 3 },
  coinbase: { name: 'Coinbase Wallet', icon: '💰', priority: 4 },
  walletconnect: { name: 'WalletConnect', icon: '🔗', priority: 5 },
  zerion: { name: 'Zerion', icon: '🟣', priority: 6 },
  phantom: { name: 'Phantom', icon: '👻', priority: 7 },
  okx: { name: 'OKX Wallet', icon: '⭕', priority: 8 },
  trust: { name: 'Trust Wallet', icon: '🛡️', priority: 9 },
  safe: { name: 'Safe', icon: '🔐', priority: 10 },
  argent: { name: 'Argent', icon: '🔷', priority: 11 },
  ledger: { name: 'Ledger', icon: '📱', priority: 12 },
  brave: { name: 'Brave Wallet', icon: '🦁', priority: 13 },
  frame: { name: 'Frame', icon: '🖼️', priority: 14 },
  taho: { name: 'Taho', icon: '🌿', priority: 15 },
};

export function useWalletDetection() {
  const [detectedWallets, setDetectedWallets] = useState<DetectedWallet[]>([]);
  const [isDetecting, setIsDetecting] = useState(true);

  useEffect(() => {
    const detectWallets = async () => {
      // Wait a bit for wallet extensions to inject
      await new Promise(resolve => setTimeout(resolve, 100));

      const wallets: DetectedWallet[] = [];

      // Check for installed wallets
      Object.entries(walletDetectors).forEach(([key, detector]) => {
        const info = walletInfo[key as keyof typeof walletInfo];
        if (info) {
          const installed = detector();
          wallets.push({
            name: info.name,
            icon: info.icon,
            installed,
            connectorId: key,
          });
        }
      });

      // Always add WalletConnect as an option
      wallets.push({
        name: walletInfo.walletconnect.name,
        icon: walletInfo.walletconnect.icon,
        installed: true, // Always available
        connectorId: 'walletconnect',
      });

      // Add other wallets that don't require installation check
      ['ledger'].forEach(key => {
        const info = walletInfo[key as keyof typeof walletInfo];
        if (info) {
          wallets.push({
            name: info.name,
            icon: info.icon,
            installed: false,
            connectorId: key,
          });
        }
      });

      // Sort by: installed first, then by priority
      wallets.sort((a, b) => {
        if (a.installed && !b.installed) return -1;
        if (!a.installed && b.installed) return 1;
        
        const aPriority = walletInfo[a.connectorId as keyof typeof walletInfo]?.priority || 999;
        const bPriority = walletInfo[b.connectorId as keyof typeof walletInfo]?.priority || 999;
        return aPriority - bPriority;
      });

      setDetectedWallets(wallets);
      setIsDetecting(false);
    };

    detectWallets();

    // Re-detect if user installs a wallet while page is open
    const interval = setInterval(detectWallets, 5000);
    return () => clearInterval(interval);
  }, []);

  return {
    detectedWallets,
    isDetecting,
    installedCount: detectedWallets.filter(w => w.installed).length,
  };
}