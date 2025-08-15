'use client';

import { useWalletDetection } from '@/hooks/useWalletDetection';
import { CheckCircle, Download } from 'lucide-react';

export function WalletInfo() {
  const { detectedWallets, isDetecting } = useWalletDetection();

  if (isDetecting) {
    return (
      <div className="p-4 text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white mx-auto"></div>
        <p className="text-white/60 text-sm mt-2">Detecting wallets...</p>
      </div>
    );
  }

  const installedWallets = detectedWallets.filter(w => w.installed);
  const availableWallets = detectedWallets.filter(w => !w.installed);

  return (
    <div className="space-y-4">
      {installedWallets.length > 0 && (
        <div>
          <h3 className="text-white/60 text-xs uppercase tracking-wider mb-2 px-4">
            Detected Wallets ({installedWallets.length})
          </h3>
          <div className="space-y-1">
            {installedWallets.map((wallet) => (
              <div
                key={wallet.connectorId}
                className="flex items-center justify-between px-4 py-2 hover:bg-white/5 transition-colors"
              >
                <div className="flex items-center space-x-3">
                  <span className="text-xl">{wallet.icon}</span>
                  <span className="text-white font-medium">{wallet.name}</span>
                </div>
                <CheckCircle className="w-4 h-4 text-green-500" />
              </div>
            ))}
          </div>
        </div>
      )}

      {availableWallets.length > 0 && (
        <div>
          <h3 className="text-white/60 text-xs uppercase tracking-wider mb-2 px-4">
            Available Wallets
          </h3>
          <div className="space-y-1">
            {availableWallets.map((wallet) => (
              <div
                key={wallet.connectorId}
                className="flex items-center justify-between px-4 py-2 hover:bg-white/5 transition-colors opacity-60"
              >
                <div className="flex items-center space-x-3">
                  <span className="text-xl">{wallet.icon}</span>
                  <span className="text-white font-medium">{wallet.name}</span>
                </div>
                <Download className="w-4 h-4 text-white/40" />
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="px-4 pt-2 border-t border-white/10">
        <p className="text-white/40 text-xs">
          Total supported wallets: 15+
        </p>
      </div>
    </div>
  );
}