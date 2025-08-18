'use client';

import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Wallet, Vault, Settings, BarChart3, Bell, Zap, ArrowLeftRight, Shield, Menu, X } from 'lucide-react';
import { usePathname } from 'next/navigation';
import { NetworkSwitcher } from './NetworkSwitcher';
import { WalletButton } from './WalletButton';
import { useWalletDetection } from '@/hooks/useWalletDetection';
import { useAccount } from 'wagmi';
import Image from 'next/image';
import { useState, useEffect } from 'react';

export function Navigation() {
  const pathname = usePathname();
  const { installedCount } = useWalletDetection();
  const { address } = useAccount();
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  // Check if user is admin (simplified check - in production, this would be more sophisticated)
  const isAdmin = address && (address.toLowerCase() === '0x1234567890123456789012345678901234567890'.toLowerCase() || pathname === '/admin');

  // Close mobile menu when route changes
  useEffect(() => {
    setIsMobileMenuOpen(false);
  }, [pathname]);

  // Close mobile menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (isMobileMenuOpen && !target.closest('.mobile-nav-container')) {
        setIsMobileMenuOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isMobileMenuOpen]);

  const navItems = [
    { href: '/dashboard', label: 'Dashboard', icon: BarChart3 },
    { href: '/vault', label: 'Vault', icon: Vault },
    { href: '/staking', label: 'Staking', icon: Zap },
    { href: '/bridge', label: 'Bridge', icon: ArrowLeftRight },
    ...(isAdmin ? [{ href: '/admin', label: 'Admin', icon: Settings }] : []),
  ];

  return (
    <header className="relative z-50 border-b border-white/10 backdrop-blur-xl bg-zinc-950/40 shadow-[0_8px_32px_0_rgba(0,0,0,0.37)]">
      <div className="container mx-auto px-4 sm:px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <div className="flex items-center">
            <Link href="/" className="relative">
              <div className="flex items-center justify-center transform hover:scale-105 transition-all duration-300">
                <Image 
                  src="/SOVA_LOGO_WHITE.svg" 
                  alt="Sova Logo" 
                  width={100} 
                  height={40} 
                  className="text-white"
                  style={{ width: 'auto', height: '40px' }}
                />
              </div>
            </Link>
          </div>

          {/* Desktop Navigation */}
          <nav className="hidden md:flex items-center space-x-2 bg-white/5 backdrop-blur-lg border border-white/10 rounded-2xl p-2">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive = pathname === item.href;
              
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`flex items-center space-x-2 px-4 py-2 rounded-xl transition-all duration-300 ${
                    isActive 
                      ? 'bg-violet-600/20 text-white shadow-[0_4px_15px_0_rgba(132,93,247,0.4)] backdrop-blur-lg border border-violet-500/30' 
                      : 'text-zinc-300 hover:bg-white/5 hover:text-white'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span className="font-medium">{item.label}</span>
                </Link>
              );
            })}
          </nav>

          {/* Mobile Menu Button */}
          <div className="md:hidden">
            <button
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              className="glass-button rounded-xl w-10 h-10 p-0 flex items-center justify-center"
            >
              {isMobileMenuOpen ? (
                <X className="w-5 h-5" />
              ) : (
                <Menu className="w-5 h-5" />
              )}
            </button>
          </div>

          {/* Right Side with Enhanced Glass Cards */}
          <div className="hidden md:flex items-center space-x-3">
            {/* Network Switcher */}
            <NetworkSwitcher />

            {/* Glass Icon Buttons */}
            <button className="glass-button rounded-xl w-10 h-10 p-0 flex items-center justify-center">
              <Bell className="w-4 h-4" />
            </button>

            <button className="glass-button rounded-xl w-10 h-10 p-0 flex items-center justify-center">
              <Settings className="w-4 h-4" />
            </button>

            {/* Wallet Connection with RainbowKit */}
            <ConnectButton.Custom>
              {({
                account,
                chain,
                openAccountModal,
                openChainModal,
                openConnectModal,
                mounted,
              }) => {
                const ready = mounted;
                const connected = ready && account && chain;

                return (
                  <div
                    {...(!ready && {
                      'aria-hidden': true,
                      'style': {
                        opacity: 0,
                        pointerEvents: 'none',
                        userSelect: 'none',
                      },
                    })}
                  >
                    {(() => {
                      if (!connected) {
                        return (
                          <button 
                            onClick={openConnectModal}
                            className="relative bg-gradient-primary bg-size-200 bg-pos-0 hover:bg-pos-100 transition-all duration-500 text-white shadow-[0_8px_25px_0_rgba(132,93,247,0.4)] hover:shadow-[0_12px_35px_0_rgba(236,72,153,0.6)] transform hover:scale-105 rounded-xl border border-white/20 backdrop-blur-sm px-4 py-2 flex items-center group"
                          >
                            <Wallet className="w-4 h-4 mr-2" />
                            <span className="font-semibold">Connect Wallet</span>
                            {installedCount > 0 && (
                              <div className="absolute -top-2 -right-2">
                                <div className="relative">
                                  <div className="absolute inset-0 bg-mint-500 rounded-full blur animate-pulse"></div>
                                  <div className="relative bg-mint-500 text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
                                    {installedCount}
                                  </div>
                                </div>
                              </div>
                            )}
                            <div className="absolute inset-0 rounded-xl bg-gradient-to-r from-violet-600/20 via-fuchsia-600/20 to-violet-600/20 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10"></div>
                          </button>
                        );
                      }

                      return <WalletButton />;
                    })()}
                  </div>
                );
              }}
            </ConnectButton.Custom>
          </div>
        </div>

        {/* Mobile Navigation Menu */}
        {isMobileMenuOpen && (
          <div className="mobile-nav-container md:hidden absolute top-full left-0 right-0 bg-slate-900 backdrop-blur-xl border-t border-white/10 shadow-xl z-40">
            <div className="container mx-auto px-4 sm:px-6 py-4">
              {/* Mobile Nav Items */}
              <nav className="space-y-2 mb-4">
                {navItems.map((item) => {
                  const Icon = item.icon;
                  const isActive = pathname === item.href;
                  
                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      onClick={() => setIsMobileMenuOpen(false)}
                      className={`flex items-center space-x-3 px-4 py-3 rounded-xl transition-all duration-300 ${
                        isActive 
                          ? 'bg-violet-600/20 text-white border border-violet-500/30' 
                          : 'text-zinc-300 hover:bg-white/5 hover:text-white'
                      }`}
                    >
                      <Icon className="w-5 h-5" />
                      <span className="font-medium">{item.label}</span>
                    </Link>
                  );
                })}
              </nav>

              {/* Mobile Utility Section */}
              <div className="border-t border-white/10 pt-4 space-y-3">
                {/* Network Switcher */}
                <NetworkSwitcher />
                
                {/* Wallet Connection */}
                <ConnectButton.Custom>
                  {({
                    account,
                    chain,
                    openAccountModal,
                    openChainModal,
                    openConnectModal,
                    mounted,
                  }) => {
                    const ready = mounted;
                    const connected = ready && account && chain;

                    return (
                      <div
                        {...(!ready && {
                          'aria-hidden': true,
                          'style': {
                            opacity: 0,
                            pointerEvents: 'none',
                            userSelect: 'none',
                          },
                        })}
                      >
                        {(() => {
                          if (!connected) {
                            return (
                              <button 
                                onClick={openConnectModal}
                                className="w-full relative bg-gradient-primary bg-size-200 bg-pos-0 hover:bg-pos-100 transition-all duration-500 text-white shadow-[0_8px_25px_0_rgba(132,93,247,0.4)] hover:shadow-[0_12px_35px_0_rgba(236,72,153,0.6)] transform hover:scale-105 rounded-xl border border-white/20 backdrop-blur-sm px-4 py-3 flex items-center justify-center group"
                              >
                                <Wallet className="w-4 h-4 mr-2" />
                                <span className="font-semibold">Connect Wallet</span>
                                {installedCount > 0 && (
                                  <div className="absolute -top-2 -right-2">
                                    <div className="relative">
                                      <div className="absolute inset-0 bg-mint-500 rounded-full blur animate-pulse"></div>
                                      <div className="relative bg-mint-500 text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
                                        {installedCount}
                                      </div>
                                    </div>
                                  </div>
                                )}
                                <div className="absolute inset-0 rounded-xl bg-gradient-to-r from-violet-600/20 via-fuchsia-600/20 to-violet-600/20 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10"></div>
                              </button>
                            );
                          }

                          return <WalletButton />;
                        })()} 
                      </div>
                    );
                  }}
                </ConnectButton.Custom>
              </div>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}