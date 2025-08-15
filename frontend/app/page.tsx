'use client';

import Link from 'next/link';
import { ArrowRight, Shield, Zap, Globe, TrendingUp } from 'lucide-react';
import { GlassCard } from '../components/GlassCard';

export default function HomePage() {
  const features = [
    {
      icon: Shield,
      title: 'Secure & Audited',
      description: 'Smart contracts audited by leading security firms with multi-sig protection',
    },
    {
      icon: Globe,
      title: 'Multi-Collateral Support',
      description: 'Deposit WBTC, tBTC, cbBTC and other Bitcoin variants seamlessly',
    },
    {
      icon: Zap,
      title: 'Instant Deposits',
      description: 'Deposit collateral and start earning yield immediately',
    },
    {
      icon: TrendingUp,
      title: 'Sustainable Yield',
      description: 'Earn consistent returns from proven DeFi strategies',
    },
  ];

  return (
    <div className="min-h-screen relative overflow-hidden">
      {/* Hero Section */}
      <section className="relative z-10 container mx-auto px-4 py-20">
        <div className="max-w-6xl mx-auto">
          <div className="text-center space-y-6 fade-in">
            {/* Hero Badge */}
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card-light">
              <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></span>
              <span className="text-sm text-gray-300">Live on Base Sepolia</span>
            </div>

            {/* Main Title */}
            <h1 className="text-6xl md:text-7xl font-bold">
              <span className="gradient-text">Multi-Collateral</span>
              <br />
              <span className="text-white">Bitcoin Vault</span>
            </h1>

            {/* Subtitle */}
            <p className="text-xl md:text-2xl text-gray-400 max-w-3xl mx-auto">
              Deposit multiple Bitcoin variants and earn sustainable yield through 
              institutional-grade DeFi strategies
            </p>

            {/* CTA Buttons */}
            <div className="flex flex-col sm:flex-row gap-4 justify-center pt-8">
              <Link
                href="/vault"
                className="btn-primary inline-flex items-center justify-center gap-2 shine-effect"
              >
                <span>Launch App</span>
                <ArrowRight className="w-5 h-5" />
              </Link>
              <a
                href="https://docs.fountfi.com"
                target="_blank"
                rel="noopener noreferrer"
                className="btn-secondary inline-flex items-center justify-center gap-2"
              >
                <span>Read Docs</span>
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="relative z-10 container mx-auto px-4 py-20">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-12 fade-in">
            <h2 className="text-4xl font-bold text-white mb-4">
              Why Choose Our Vault?
            </h2>
            <p className="text-xl text-gray-400">
              Built on battle-tested FountFi infrastructure
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {features.map((feature, index) => {
              const Icon = feature.icon;
              return (
                <GlassCard
                  key={feature.title}
                  variant="dark"
                  hover
                  className="fade-in"
                  style={{ animationDelay: `${index * 0.1}s` }}
                >
                  <div className="p-6 space-y-4">
                    <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
                      <Icon className="w-6 h-6 text-white" />
                    </div>
                    <h3 className="text-xl font-semibold text-white">
                      {feature.title}
                    </h3>
                    <p className="text-gray-400">
                      {feature.description}
                    </p>
                  </div>
                </GlassCard>
              );
            })}
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="relative z-10 container mx-auto px-4 py-20">
        <div className="max-w-6xl mx-auto">
          <GlassCard variant="premium" className="overflow-hidden">
            <div className="p-12">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-8 text-center">
                <div className="space-y-2">
                  <p className="text-4xl font-bold gradient-text">$0M+</p>
                  <p className="text-gray-400">Total Value Locked</p>
                </div>
                <div className="space-y-2">
                  <p className="text-4xl font-bold gradient-text">0%</p>
                  <p className="text-gray-400">Average APY</p>
                </div>
                <div className="space-y-2">
                  <p className="text-4xl font-bold gradient-text">0+</p>
                  <p className="text-gray-400">Active Users</p>
                </div>
              </div>
            </div>
            
            {/* Decorative gradient */}
            <div className="absolute inset-0 bg-gradient-to-br from-blue-500/10 via-transparent to-purple-500/10 pointer-events-none"></div>
          </GlassCard>
        </div>
      </section>

      {/* CTA Section */}
      <section className="relative z-10 container mx-auto px-4 py-20">
        <div className="max-w-4xl mx-auto text-center">
          <GlassCard variant="dark" className="p-12">
            <h2 className="text-4xl font-bold text-white mb-4">
              Ready to Start Earning?
            </h2>
            <p className="text-xl text-gray-400 mb-8">
              Join the most secure multi-collateral Bitcoin vault on Base
            </p>
            <Link
              href="/vault"
              className="btn-primary inline-flex items-center gap-2 text-lg px-8 py-4 shine-effect"
            >
              <span>Access Vault</span>
              <ArrowRight className="w-5 h-5" />
            </Link>
          </GlassCard>
        </div>
      </section>

      {/* Background Effects */}
      <div className="fixed inset-0 pointer-events-none">
        <div className="absolute top-20 left-20 w-72 h-72 bg-blue-500/20 rounded-full filter blur-[100px] animate-pulse"></div>
        <div className="absolute bottom-20 right-20 w-96 h-96 bg-purple-500/20 rounded-full filter blur-[120px] animate-pulse" style={{ animationDelay: '2s' }}></div>
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-pink-500/10 rounded-full filter blur-[150px] animate-pulse" style={{ animationDelay: '4s' }}></div>
      </div>
    </div>
  );
}