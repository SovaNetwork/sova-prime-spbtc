'use client';

import { useState } from 'react';
import { GlassCard } from '@/components/GlassCard';
import { ArrowLeftRight, Rocket, Bell, Mail } from 'lucide-react';

export default function BridgePage() {
  const [email, setEmail] = useState('');
  const [isSubscribed, setIsSubscribed] = useState(false);

  const handleSubscribe = (e: React.FormEvent) => {
    e.preventDefault();
    if (email) {
      setIsSubscribed(true);
      setEmail('');
      // In production, this would send the email to a backend service
      setTimeout(() => setIsSubscribed(false), 3000);
    }
  };

  return (
    <main className="container mx-auto px-6 py-12">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-12">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-r from-blue-500 to-mint-500 rounded-full mb-6">
            <ArrowLeftRight className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-5xl font-bold text-white mb-4">Cross-Chain Bridge</h1>
          <p className="text-xl text-white/60">Coming Soon</p>
        </div>

        <GlassCard className="mb-8">
          <div className="text-center py-8">
            <Rocket className="w-16 h-16 text-white/40 mx-auto mb-6" />
            <h2 className="text-2xl font-semibold text-white mb-4">
              We're Building Something Amazing
            </h2>
            <p className="text-white/60 mb-6 max-w-2xl mx-auto">
              Our cross-chain bridge will enable seamless transfer of your BTC vault shares 
              across multiple blockchain networks. Move your assets between Base, Ethereum, 
              Arbitrum, Optimism, and more with just a few clicks.
            </p>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
              <div className="p-6 bg-white/5 rounded-xl">
                <div className="w-12 h-12 bg-gradient-to-r from-green-500 to-emerald-500 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <span className="text-white text-xl">⚡</span>
                </div>
                <h3 className="text-white font-semibold mb-2">Fast Transfers</h3>
                <p className="text-white/60 text-sm">
                  Bridge your assets in minutes, not hours
                </p>
              </div>
              
              <div className="p-6 bg-white/5 rounded-xl">
                <div className="w-12 h-12 bg-gradient-to-r from-blue-500 to-mint-500 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <span className="text-white text-xl">🔒</span>
                </div>
                <h3 className="text-white font-semibold mb-2">Secure</h3>
                <p className="text-white/60 text-sm">
                  Battle-tested security with multi-sig protection
                </p>
              </div>
              
              <div className="p-6 bg-white/5 rounded-xl">
                <div className="w-12 h-12 bg-gradient-to-r from-orange-500 to-yellow-500 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <span className="text-white text-xl">💰</span>
                </div>
                <h3 className="text-white font-semibold mb-2">Low Fees</h3>
                <p className="text-white/60 text-sm">
                  Competitive rates for all bridge transfers
                </p>
              </div>
            </div>
          </div>
        </GlassCard>

        <GlassCard>
          <div className="text-center">
            <Bell className="w-12 h-12 text-white/40 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-white mb-2">
              Get Notified When We Launch
            </h3>
            <p className="text-white/60 mb-6">
              Be the first to know when our cross-chain bridge goes live
            </p>
            
            <form onSubmit={handleSubscribe} className="max-w-md mx-auto">
              <div className="flex gap-2">
                <input
                  type="email"
                  placeholder="Enter your email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="flex-1 px-4 py-3 bg-white/10 backdrop-blur-sm border border-white/20 rounded-xl text-white placeholder-white/40 focus:outline-none focus:border-white/40"
                  required
                />
                <button
                  type="submit"
                  className="px-6 py-3 bg-gradient-to-r from-blue-500 to-mint-500 text-white rounded-xl hover:shadow-[0_8px_25px_0_rgba(59,130,246,0.4)] transition-all duration-300"
                >
                  <Mail className="w-5 h-5" />
                </button>
              </div>
              {isSubscribed && (
                <p className="mt-3 text-green-400 text-sm">
                  Thanks for subscribing! We'll notify you when the bridge launches.
                </p>
              )}
            </form>
          </div>
        </GlassCard>

        <div className="mt-12 text-center">
          <p className="text-white/40 text-sm">
            Expected Launch: Q2 2024 • Follow us for updates
          </p>
        </div>
      </div>
    </main>
  );
}