'use client';

import { useState, useEffect } from 'react';
import { Smartphone, QrCode, ArrowRight, X } from 'lucide-react';
import { useConnect } from 'wagmi';
import { walletInfo } from '@/hooks/useWalletDetection';

const mobileWallets = [
  { 
    id: 'metamask', 
    name: 'MetaMask', 
    icon: '🦊',
    deepLink: 'metamask://open',
    universalLink: 'https://metamask.app.link/open',
  },
  { 
    id: 'rainbow', 
    name: 'Rainbow', 
    icon: '🌈',
    deepLink: 'rainbow://open',
    universalLink: 'https://rainbow.me/app/open',
  },
  { 
    id: 'coinbase', 
    name: 'Coinbase Wallet', 
    icon: '💰',
    deepLink: 'cbwallet://open',
    universalLink: 'https://go.cb-w.com/open',
  },
  { 
    id: 'trust', 
    name: 'Trust Wallet', 
    icon: '🛡️',
    deepLink: 'trust://open',
    universalLink: 'https://link.trustwallet.com/open',
  },
  { 
    id: 'zerion', 
    name: 'Zerion', 
    icon: '🟣',
    deepLink: 'zerion://open',
    universalLink: 'https://app.zerion.io/open',
  },
];

interface MobileWalletConnectProps {
  isOpen: boolean;
  onClose: () => void;
}

export function MobileWalletConnect({ isOpen, onClose }: MobileWalletConnectProps) {
  const { connectors } = useConnect();
  const [isMobile, setIsMobile] = useState(false);
  const [showQR, setShowQR] = useState(false);

  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(/iPhone|iPad|iPod|Android/i.test(navigator.userAgent));
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  const handleMobileWalletClick = (wallet: typeof mobileWallets[0]) => {
    if (isMobile) {
      // Try deep link first, fallback to universal link
      window.location.href = wallet.deepLink;
      setTimeout(() => {
        window.location.href = wallet.universalLink;
      }, 1500);
    } else {
      // Show QR code for desktop users
      setShowQR(true);
    }
  };

  const walletConnectConnector = connectors.find(c => c.id === 'walletConnect' || c.name.includes('WalletConnect'));

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onClose}
      />
      
      {/* Modal */}
      <div className="relative bg-slate-900/95 backdrop-blur-xl border border-white/10 rounded-2xl shadow-[0_8px_32px_0_rgba(31,38,135,0.37)] max-w-md w-full overflow-hidden">
        {/* Header */}
        <div className="p-6 border-b border-white/10">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Smartphone className="w-6 h-6 text-white" />
              <h2 className="text-xl font-semibold text-white">
                {isMobile ? 'Select Wallet' : 'Connect Mobile Wallet'}
              </h2>
            </div>
            <button
              onClick={onClose}
              className="p-2 hover:bg-white/10 rounded-lg transition-colors"
            >
              <X className="w-5 h-5 text-white/60" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6">
          {showQR && !isMobile ? (
            <div className="text-center space-y-4">
              <div className="bg-white p-4 rounded-xl inline-block">
                <QrCode className="w-48 h-48 text-slate-900" />
              </div>
              <p className="text-white/60 text-sm">
                Scan with your mobile wallet to connect
              </p>
              <button
                onClick={() => setShowQR(false)}
                className="text-blue-400 hover:text-blue-300 text-sm"
              >
                Back to wallet list
              </button>
            </div>
          ) : (
            <div className="space-y-2">
              {mobileWallets.map((wallet) => (
                <button
                  key={wallet.id}
                  onClick={() => handleMobileWalletClick(wallet)}
                  className="w-full flex items-center justify-between p-4 bg-white/5 hover:bg-white/10 rounded-xl transition-all duration-300 group"
                >
                  <div className="flex items-center space-x-3">
                    <span className="text-2xl">{wallet.icon}</span>
                    <div className="text-left">
                      <div className="text-white font-medium">{wallet.name}</div>
                      {isMobile && (
                        <div className="text-white/40 text-xs">Tap to open</div>
                      )}
                    </div>
                  </div>
                  <ArrowRight className="w-4 h-4 text-white/40 group-hover:text-white/60 transition-colors" />
                </button>
              ))}

              {/* WalletConnect Option */}
              {walletConnectConnector && (
                <button
                  onClick={() => setShowQR(true)}
                  className="w-full flex items-center justify-between p-4 bg-gradient-to-r from-blue-600/10 to-purple-600/10 hover:from-blue-600/20 hover:to-purple-600/20 border border-white/10 rounded-xl transition-all duration-300 group mt-4"
                >
                  <div className="flex items-center space-x-3">
                    <span className="text-2xl">🔗</span>
                    <div className="text-left">
                      <div className="text-white font-medium">WalletConnect</div>
                      <div className="text-white/40 text-xs">100+ wallets supported</div>
                    </div>
                  </div>
                  <QrCode className="w-4 h-4 text-white/40 group-hover:text-white/60 transition-colors" />
                </button>
              )}
            </div>
          )}

          {/* Info */}
          <div className="mt-6 p-4 bg-blue-600/10 border border-blue-600/20 rounded-xl">
            <p className="text-white/60 text-xs">
              {isMobile 
                ? "Select your wallet app to connect. Make sure you have the app installed."
                : "Use your mobile wallet to scan the QR code or select a wallet to see connection options."
              }
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}