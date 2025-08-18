'use client';

import React from 'react';
import { cn } from '../lib/utils';

interface GlassCardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
  variant?: 'dark' | 'light' | 'premium';
  animation?: 'floating' | 'pulse' | 'none';
  onClick?: () => void;
  style?: React.CSSProperties;
}

export function GlassCard({ 
  children, 
  className = '', 
  hover = true,
  variant = 'dark',
  animation = 'none',
  onClick,
  style = {}
}: GlassCardProps) {
  const getVariantStyles = () => {
    // All variants now use the same clean style like Transaction History card
    return {
      background: 'rgba(255, 255, 255, 0.05)',
      backdropFilter: 'blur(48px)',
      WebkitBackdropFilter: 'blur(48px)',
      border: '1px solid rgba(255, 255, 255, 0.1)',
    };
  };

  const baseClasses = cn(
    'rounded-2xl p-6 transition-all duration-500',
    {
      'cursor-pointer hover:transform hover:scale-[1.02] hover:-translate-y-2': hover && onClick,
      'floating-animation': animation === 'floating',
      'pulse-glow': animation === 'pulse'
    },
    className
  );

  return (
    <div 
      className={baseClasses} 
      onClick={onClick}
      style={{
        ...getVariantStyles(),
        ...style
      }}
    >
      {children}
    </div>
  );
}

interface GlassCardHeaderProps {
  title: string;
  subtitle?: string;
  icon?: React.ReactNode;
  action?: React.ReactNode;
}

export function GlassCardHeader({ title, subtitle, icon, action }: GlassCardHeaderProps) {
  return (
    <div className="flex items-start justify-between mb-6">
      <div className="flex items-start gap-3">
        {icon && (
          <div className="p-2 rounded-lg bg-white/5 text-blue-400">
            {icon}
          </div>
        )}
        <div>
          <h3 className="text-xl font-semibold text-white">{title}</h3>
          {subtitle && (
            <p className="text-sm text-gray-400 mt-1">{subtitle}</p>
          )}
        </div>
      </div>
      {action && (
        <div>{action}</div>
      )}
    </div>
  );
}

interface GlassCardContentProps {
  children: React.ReactNode;
  className?: string;
}

export function GlassCardContent({ children, className = '' }: GlassCardContentProps) {
  return (
    <div className={cn('space-y-4', className)}>
      {children}
    </div>
  );
}

interface GlassCardFooterProps {
  children: React.ReactNode;
  className?: string;
}

export function GlassCardFooter({ children, className = '' }: GlassCardFooterProps) {
  return (
    <div className={cn('mt-6 pt-6 border-t border-white/10', className)}>
      {children}
    </div>
  );
}

// Composite export for convenience
export const Card = {
  Root: GlassCard,
  Header: GlassCardHeader,
  Content: GlassCardContent,
  Footer: GlassCardFooter
};