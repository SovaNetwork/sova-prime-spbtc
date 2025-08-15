'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WagmiProvider } from 'wagmi';
import { RainbowKitProvider, darkTheme, Theme } from '@rainbow-me/rainbowkit';
import { ApolloProvider } from '@apollo/client';
import { config } from '@/lib/wagmi';
import apolloClient from '@/lib/apollo-client';
import '@rainbow-me/rainbowkit/styles.css';
import merge from 'lodash.merge';

const queryClient = new QueryClient();

// Custom glassmorphism theme for RainbowKit with new colors
const customTheme = merge(darkTheme(), {
  colors: {
    accentColor: 'linear-gradient(135deg, #845EF7 0%, #EC4899 100%)', // Violet to fuchsia gradient
    accentColorForeground: '#FFFFFF',
    actionButtonBorder: 'rgba(255, 255, 255, 0.08)',
    actionButtonBorderMobile: 'rgba(255, 255, 255, 0.08)',
    actionButtonSecondaryBackground: 'rgba(255, 255, 255, 0.05)',
    closeButton: 'rgba(255, 255, 255, 0.7)',
    closeButtonBackground: 'rgba(255, 255, 255, 0.05)',
    connectButtonBackground: '#1A0E1A',
    connectButtonBackgroundError: '#C8325D',
    connectButtonInnerBackground: 'linear-gradient(135deg, #845EF7 0%, #EC4899 100%)',
    connectButtonText: '#FFFFFF',
    connectButtonTextError: '#FFFFFF',
    connectionIndicator: '#A8E4A0',
    error: '#C8325D',
    generalBorder: 'rgba(255, 255, 255, 0.08)',
    generalBorderDim: 'rgba(255, 255, 255, 0.04)',
    menuItemBackground: 'rgba(255, 255, 255, 0.05)',
    modalBackdrop: 'rgba(0, 0, 0, 0.6)',
    modalBackground: 'rgba(26, 14, 26, 0.95)',
    modalBorder: 'rgba(255, 255, 255, 0.08)',
    modalText: 'rgba(255, 255, 255, 0.9)',
    modalTextDim: 'rgba(255, 255, 255, 0.6)',
    modalTextSecondary: 'rgba(255, 255, 255, 0.5)',
    profileAction: 'rgba(255, 255, 255, 0.05)',
    profileActionHover: 'rgba(255, 255, 255, 0.1)',
    profileForeground: 'rgba(26, 14, 26, 0.95)',
    selectedOptionBorder: 'rgba(132, 94, 247, 0.5)',
    standby: '#FFB86C',
  },
  fonts: {
    body: 'Inter, sans-serif',
  },
  radii: {
    actionButton: '12px',
    connectButton: '12px',
    menuButton: '12px',
    modal: '16px',
    modalMobile: '16px',
  },
  shadows: {
    connectButton: '0 8px 25px 0 rgba(132, 94, 247, 0.4)',
    dialog: '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
    profileDetailsAction: '0 4px 15px 0 rgba(0, 0, 0, 0.2)',
    selectedOption: '0 4px 15px 0 rgba(132, 94, 247, 0.4)',
    selectedWallet: '0 4px 15px 0 rgba(132, 94, 247, 0.4)',
    walletLogo: '0 4px 15px 0 rgba(0, 0, 0, 0.2)',
  },
  blurs: {
    modalOverlay: 'blur(8px)',
  },
} as Theme);

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ApolloProvider client={apolloClient}>
          <RainbowKitProvider 
            theme={customTheme}
            modalSize="wide"
            showRecentTransactions={true}
          >
            {children}
          </RainbowKitProvider>
        </ApolloProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}