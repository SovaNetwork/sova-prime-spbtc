import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { 
  metaMaskWallet,
  rainbowWallet,
  coinbaseWallet,
  argentWallet,
  trustWallet,
  ledgerWallet,
  walletConnectWallet,
  rabbyWallet,
  safeWallet,
  zerionWallet,
  phantomWallet,
  okxWallet,
  braveWallet,
  frameWallet,
  tahoWallet,
} from '@rainbow-me/rainbowkit/wallets';
import { baseSepolia, base, mainnet, arbitrum, optimism } from 'wagmi/chains';

// Group wallets for better organization
const walletGroups = [
  {
    groupName: 'Popular',
    wallets: [
      metaMaskWallet,
      rabbyWallet,
      rainbowWallet,
      coinbaseWallet,
      walletConnectWallet,
    ],
  },
  {
    groupName: 'More Wallets',
    wallets: [
      zerionWallet,
      phantomWallet,
      okxWallet,
      trustWallet,
      safeWallet,
      argentWallet,
      ledgerWallet,
      braveWallet,
      frameWallet,
      tahoWallet,
    ],
  },
];

export const config = getDefaultConfig({
  appName: 'Multi-Collateral BTC Vault',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'fbdc02ca1d45b13459b8815d9344ee5a',
  chains: [baseSepolia, base, mainnet, arbitrum, optimism],
  wallets: walletGroups,
  ssr: true,
});