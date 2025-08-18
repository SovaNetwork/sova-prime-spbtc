'use client';

import { useState, useEffect } from 'react';
import { useAccount, useBalance, useChainId } from 'wagmi';
import { formatUnits } from 'viem';
import { CheckCircle, Circle, ArrowRight, X, Sparkles, ExternalLink } from 'lucide-react';
import { WalletConnect } from './WalletConnect';

interface OnboardingStep {
  id: string;
  title: string;
  description: string;
  action?: () => void;
  completed: boolean;
  optional?: boolean;
}

interface OnboardingWizardProps {
  onComplete?: () => void;
  onSkip?: () => void;
}

export default function OnboardingWizard({ onComplete, onSkip }: OnboardingWizardProps) {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const [currentStep, setCurrentStep] = useState(0);
  const [showWizard, setShowWizard] = useState(true);
  const [hasCompletedBefore, setHasCompletedBefore] = useState(false);

  // Check token balances
  const { data: wbtcBalance } = useBalance({
    address,
    token: process.env.NEXT_PUBLIC_WBTC_ADDRESS as `0x${string}`,
  });

  const { data: tbtcBalance } = useBalance({
    address,
    token: process.env.NEXT_PUBLIC_TBTC_ADDRESS as `0x${string}`,
  });

  const { data: sovaBtcBalance } = useBalance({
    address,
    token: process.env.NEXT_PUBLIC_SOVABTC_ADDRESS as `0x${string}`,
  });

  // Check if user has completed onboarding before
  useEffect(() => {
    if (address) {
      const completed = localStorage.getItem(`onboarding_completed_${address}`);
      setHasCompletedBefore(!!completed);
    }
  }, [address]);

  const steps: OnboardingStep[] = [
    {
      id: 'connect',
      title: 'Connect Your Wallet',
      description: 'Connect your Web3 wallet to interact with the vault',
      completed: isConnected,
    },
    {
      id: 'network',
      title: 'Switch to Base Sepolia',
      description: 'Ensure you are on the Base Sepolia testnet',
      completed: chainId === 84532,
      action: async () => {
        if (window.ethereum) {
          try {
            await window.ethereum.request({
              method: 'wallet_switchEthereumChain',
              params: [{ chainId: '0x14A34' }], // 84532 in hex
            });
          } catch (error: any) {
            if (error.code === 4902) {
              await window.ethereum.request({
                method: 'wallet_addEthereumChain',
                params: [{
                  chainId: '0x14A34',
                  chainName: 'Base Sepolia',
                  nativeCurrency: {
                    name: 'ETH',
                    symbol: 'ETH',
                    decimals: 18,
                  },
                  rpcUrls: ['https://sepolia.base.org'],
                  blockExplorerUrls: ['https://sepolia.basescan.org'],
                }],
              });
            }
          }
        }
      },
    },
    {
      id: 'faucet',
      title: 'Get Test Tokens',
      description: 'Claim test BTC tokens from our faucet',
      completed: (wbtcBalance?.value ?? BigInt(0)) > BigInt(0) || (tbtcBalance?.value ?? BigInt(0)) > BigInt(0) || (sovaBtcBalance?.value ?? BigInt(0)) > BigInt(0),
      action: () => {
        window.open('https://sepolia.basescan.org/address/0xe44b2870eFcd6Bb3C9305808012621f438e9636D#writeContract', '_blank');
      },
    },
    {
      id: 'approve',
      title: 'Approve Token Spending',
      description: 'Approve the vault to use your BTC tokens',
      completed: false, // This would need contract interaction to check
      optional: true,
    },
    {
      id: 'deposit',
      title: 'Make Your First Deposit',
      description: 'Deposit BTC collateral to receive stSOVABTC shares',
      completed: false, // This would need contract interaction to check
      optional: true,
    },
    {
      id: 'explore',
      title: 'Explore Features',
      description: 'Learn about redemptions, yields, and vault stats',
      completed: currentStep >= 5,
    },
  ];

  const handleComplete = () => {
    if (address) {
      localStorage.setItem(`onboarding_completed_${address}`, 'true');
    }
    setShowWizard(false);
    onComplete?.();
  };

  const handleSkip = () => {
    setShowWizard(false);
    onSkip?.();
  };

  const nextStep = () => {
    if (currentStep < steps.length - 1) {
      setCurrentStep(currentStep + 1);
    } else {
      handleComplete();
    }
  };

  const prevStep = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };

  if (!showWizard) {
    return null;
  }

  const currentStepData = steps[currentStep];
  const progress = ((currentStep + 1) / steps.length) * 100;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-gray-900 rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden shadow-2xl">
        {/* Header */}
        <div className="bg-gradient-to-r from-blue-600 to-mint-600 p-6 relative">
          <button
            onClick={handleSkip}
            className="absolute top-4 right-4 text-white/80 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
          
          <div className="flex items-center gap-3 mb-4">
            <Sparkles className="w-8 h-8 text-yellow-300" />
            <h2 className="text-2xl font-bold text-white">Welcome to FountFi Vault!</h2>
          </div>
          
          {/* Progress bar */}
          <div className="w-full bg-white/20 rounded-full h-2">
            <div 
              className="bg-white rounded-full h-2 transition-all duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>

        {/* Content */}
        <div className="p-6">
          {/* Steps indicator */}
          <div className="flex items-center justify-between mb-8">
            {steps.map((step, index) => (
              <div key={step.id} className="flex items-center">
                <div className="flex flex-col items-center">
                  <div className={`
                    w-10 h-10 rounded-full flex items-center justify-center transition-all
                    ${step.completed ? 'bg-green-500 text-white' : 
                      index === currentStep ? 'bg-blue-500 text-white' : 
                      'bg-gray-700 text-gray-400'}
                  `}>
                    {step.completed ? (
                      <CheckCircle className="w-6 h-6" />
                    ) : (
                      <Circle className="w-6 h-6" />
                    )}
                  </div>
                  <span className="text-xs mt-2 text-gray-400 hidden sm:block">
                    {step.title.split(' ')[0]}
                  </span>
                </div>
                {index < steps.length - 1 && (
                  <div className={`
                    h-0.5 w-8 sm:w-16 mx-2 transition-all
                    ${step.completed ? 'bg-green-500' : 'bg-gray-700'}
                  `} />
                )}
              </div>
            ))}
          </div>

          {/* Current step content */}
          <div className="min-h-[200px]">
            <h3 className="text-xl font-semibold text-white mb-3">
              Step {currentStep + 1}: {currentStepData.title}
            </h3>
            <p className="text-gray-300 mb-6">
              {currentStepData.description}
            </p>

            {/* Step-specific content */}
            {currentStepData.id === 'connect' && !isConnected && (
              <div className="bg-gray-800 rounded-lg p-4">
                <WalletConnect />
              </div>
            )}

            {currentStepData.id === 'network' && chainId !== 84532 && (
              <button
                onClick={currentStepData.action}
                className="bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg transition-colors flex items-center gap-2"
              >
                Switch Network
                <ExternalLink className="w-4 h-4" />
              </button>
            )}

            {currentStepData.id === 'faucet' && (
              <div className="space-y-4">
                <div className="bg-gray-800 rounded-lg p-4">
                  <h4 className="text-sm font-medium text-gray-400 mb-2">Your Test Token Balances:</h4>
                  <div className="space-y-2">
                    <div className="flex justify-between">
                      <span className="text-gray-300">WBTC:</span>
                      <span className="text-white font-mono">
                        {wbtcBalance ? formatUnits(wbtcBalance.value, 8) : '0'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-300">tBTC:</span>
                      <span className="text-white font-mono">
                        {tbtcBalance ? formatUnits(tbtcBalance.value, 18) : '0'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-300">sovaBTC:</span>
                      <span className="text-white font-mono">
                        {sovaBtcBalance ? formatUnits(sovaBtcBalance.value, 18) : '0'}
                      </span>
                    </div>
                  </div>
                </div>
                
                <button
                  onClick={currentStepData.action}
                  className="bg-green-500 hover:bg-green-600 text-white px-6 py-3 rounded-lg transition-colors flex items-center gap-2"
                >
                  Open Token Faucet
                  <ExternalLink className="w-4 h-4" />
                </button>
              </div>
            )}

            {currentStepData.id === 'explore' && (
              <div className="bg-gray-800 rounded-lg p-4 space-y-3">
                <div className="flex items-start gap-3">
                  <CheckCircle className="w-5 h-5 text-green-500 mt-0.5" />
                  <div>
                    <h4 className="text-white font-medium">Multi-Collateral Deposits</h4>
                    <p className="text-gray-400 text-sm">Accept WBTC, tBTC, and sovaBTC</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <CheckCircle className="w-5 h-5 text-green-500 mt-0.5" />
                  <div>
                    <h4 className="text-white font-medium">14-Day Redemption Queue</h4>
                    <p className="text-gray-400 text-sm">Secure withdrawal process</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <CheckCircle className="w-5 h-5 text-green-500 mt-0.5" />
                  <div>
                    <h4 className="text-white font-medium">Yield Generation</h4>
                    <p className="text-gray-400 text-sm">Earn returns on your BTC</p>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Navigation buttons */}
          <div className="flex justify-between items-center mt-8">
            <button
              onClick={prevStep}
              disabled={currentStep === 0}
              className="text-gray-400 hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Previous
            </button>

            <div className="flex gap-3">
              {hasCompletedBefore && (
                <button
                  onClick={handleSkip}
                  className="text-gray-400 hover:text-white transition-colors"
                >
                  Skip Tutorial
                </button>
              )}
              
              <button
                onClick={nextStep}
                disabled={!currentStepData.completed && !currentStepData.optional}
                className="bg-blue-500 hover:bg-blue-600 disabled:bg-gray-700 disabled:cursor-not-allowed text-white px-6 py-2 rounded-lg transition-colors flex items-center gap-2"
              >
                {currentStep === steps.length - 1 ? 'Complete' : 'Next'}
                <ArrowRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}