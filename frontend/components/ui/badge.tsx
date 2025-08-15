import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const badgeVariants = cva(
  'inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2',
  {
    variants: {
      variant: {
        default:
          'border-transparent bg-orange-500/20 text-orange-500',
        secondary:
          'border-transparent bg-zinc-800/50 text-zinc-300',
        destructive:
          'border-transparent bg-red-500/20 text-red-500',
        outline: 'text-zinc-300 border-zinc-700',
        success: 'border-transparent bg-green-500/20 text-green-500',
        warning: 'border-transparent bg-yellow-500/20 text-yellow-500',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  }
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  )
}

export { Badge, badgeVariants }