'use client';

import { useState } from 'react';
import { GlassCard } from '@/components/GlassCard';
import { Zap, Trophy, Gift, TrendingUp, Mail } from 'lucide-react';

export default function StakingPage() {
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
          <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-full mb-6">
            <Zap className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-5xl font-bold text-white mb-4">Staking Rewards</h1>
          <p className="text-xl text-white/60">Coming Soon</p>
        </div>

        <GlassCard className="mb-8">
          <div className="text-center py-8">
            <Trophy className="w-16 h-16 text-yellow-400 mx-auto mb-6" />
            <h2 className="text-2xl font-semibold text-white mb-4">
              Earn Extra Rewards by Staking
            </h2>
            <p className="text-white/60 mb-6 max-w-2xl mx-auto">
              Soon you'll be able to stake your btcVault tokens to earn additional rewards. 
              Participate in governance, boost your APY, and unlock exclusive benefits 
              as a long-term vault participant.
            </p>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
              <div className="p-6 bg-white/5 rounded-xl">
                <div className="w-12 h-12 bg-gradient-to-r from-green-500 to-emerald-500 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <TrendingUp className="w-6 h-6 text-white" />
                </div>
                <h3 className="text-white font-semibold mb-2">Boosted APY</h3>
                <p className="text-white/60 text-sm">
                  Earn up to 2x rewards on your staked tokens
                </p>
              </div>
              
              <div className="p-6 bg-white/5 rounded-xl">
                <div className="w-12 h-12 bg-gradient-to-r from-mint-500 to-pink-500 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <Gift className="w-6 h-6 text-white" />
                </div>
                <h3 className="text-white font-semibold mb-2">Exclusive Perks</h3>
                <p className="text-white/60 text-sm">
                  Access to premium features and airdrops
                </p>
              </div>
              
              <div className="p-6 bg-white/5 rounded-xl">
                <div className="w-12 h-12 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <span className="text-white text-xl">🗳️</span>
                </div>
                <h3 className="text-white font-semibold mb-2">Governance</h3>
                <p className="text-white/60 text-sm">
                  Vote on protocol upgrades and proposals
                </p>
              </div>
            </div>
          </div>
        </GlassCard>

        <GlassCard className="mb-8">
          <h3 className="text-xl font-semibold text-white mb-4">Staking Tiers Preview</h3>
          <div className="space-y-4">
            <div className="p-4 bg-gradient-to-r from-gray-500/10 to-gray-600/10 rounded-xl border border-gray-500/20">
              <div className="flex items-center justify-between mb-2">
                <span className="text-white font-medium">Bronze Tier</span>
                <span className="text-gray-400 text-sm">1-100 btcVault</span>
              </div>
              <div className="text-white/60 text-sm">
                • Base staking rewards • 1x voting power • Monthly airdrops
              </div>
            </div>
            
            <div className="p-4 bg-gradient-to-r from-yellow-500/10 to-orange-500/10 rounded-xl border border-yellow-500/20">
              <div className="flex items-center justify-between mb-2">
                <span className="text-white font-medium">Gold Tier</span>
                <span className="text-yellow-400 text-sm">100-1000 btcVault</span>
              </div>
              <div className="text-white/60 text-sm">
                • 1.5x staking rewards • 2x voting power • Weekly airdrops • Priority support
              </div>
            </div>
            
            <div className="p-4 bg-gradient-to-r from-mint-500/10 to-pink-500/10 rounded-xl border border-mint-500/20">
              <div className="flex items-center justify-between mb-2">
                <span className="text-white font-medium">Diamond Tier</span>
                <span className="text-mint-400 text-sm">1000+ btcVault</span>
              </div>
              <div className="text-white/60 text-sm">
                • 2x staking rewards • 3x voting power • Daily airdrops • VIP access • Exclusive NFTs
              </div>
            </div>
          </div>
        </GlassCard>

        <GlassCard>
          <div className="text-center">
            <Mail className="w-12 h-12 text-white/40 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-white mb-2">
              Be First to Stake
            </h3>
            <p className="text-white/60 mb-6">
              Get early access when staking launches
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
                  className="px-6 py-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-white rounded-xl hover:shadow-[0_8px_25px_0_rgba(132,242,155,0.4)] transition-all duration-300"
                >
                  Notify Me
                </button>
              </div>
              {isSubscribed && (
                <p className="mt-3 text-green-400 text-sm">
                  Thanks! We'll notify you when staking goes live.
                </p>
              )}
            </form>
          </div>
        </GlassCard>

        <div className="mt-12 text-center">
          <p className="text-white/40 text-sm">
            Expected Launch: Q2 2024 • Join our community for updates
          </p>
        </div>
      </div>
    </main>
  );
}