import { useState, useEffect, useCallback } from 'react'
import toast from 'react-hot-toast'

interface ToastOptions {
  title?: string
  description?: string
  variant?: 'default' | 'destructive' | 'success'
  duration?: number
}

export function useToast() {
  const showToast = useCallback(({ title, description, variant = 'default', duration = 4000 }: ToastOptions) => {
    const message = title ? `${title}${description ? '\n' + description : ''}` : description || ''
    
    switch (variant) {
      case 'destructive':
        toast.error(message, { duration })
        break
      case 'success':
        toast.success(message, { duration })
        break
      default:
        toast(message, { duration })
    }
  }, [])

  return {
    toast: showToast,
  }
}