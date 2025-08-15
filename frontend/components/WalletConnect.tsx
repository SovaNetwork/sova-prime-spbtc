'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';

export function WalletConnect() {
  return (
    <ConnectButton 
      chainStatus="icon"
      showBalance={{
        smallScreen: false,
        largeScreen: true,
      }}
    />
  );
}