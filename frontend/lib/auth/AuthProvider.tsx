'use client';

import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';

interface User {
  id: string;
  email: string;
  role: 'SUPER_ADMIN' | 'ADMIN' | 'OPERATOR' | 'VIEWER';
  isActive: boolean;
  lastLogin: string | null;
  createdAt: string;
  updatedAt: string;
}

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: (allSessions?: boolean) => Promise<void>;
  refreshToken: () => Promise<boolean>;
  hasRole: (role: User['role']) => boolean;
  hasPermission: (requiredRole: User['role']) => boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  children: React.ReactNode;
}

const roleHierarchy: Record<User['role'], number> = {
  VIEWER: 1,
  OPERATOR: 2,
  ADMIN: 3,
  SUPER_ADMIN: 4,
};

export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();

  // Check if user has a specific role
  const hasRole = useCallback((role: User['role']): boolean => {
    return user?.role === role;
  }, [user]);

  // Check if user has permission (role or higher)
  const hasPermission = useCallback((requiredRole: User['role']): boolean => {
    if (!user) return false;
    return roleHierarchy[user.role] >= roleHierarchy[requiredRole];
  }, [user]);

  // Refresh access token using refresh token
  const refreshToken = useCallback(async (): Promise<boolean> => {
    try {
      const refreshToken = localStorage.getItem('refreshToken');
      if (!refreshToken) {
        return false;
      }

      const response = await fetch('/api/auth/refresh', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ refreshToken }),
      });

      if (!response.ok) {
        // Refresh token is invalid or expired
        localStorage.removeItem('accessToken');
        localStorage.removeItem('refreshToken');
        localStorage.removeItem('tokenExpiresAt');
        localStorage.removeItem('refreshExpiresAt');
        localStorage.removeItem('user');
        setUser(null);
        return false;
      }

      const data = await response.json();
      const { tokens } = data;

      // Update stored tokens
      localStorage.setItem('accessToken', tokens.accessToken);
      localStorage.setItem('refreshToken', tokens.refreshToken);
      localStorage.setItem('tokenExpiresAt', tokens.expiresAt);
      localStorage.setItem('refreshExpiresAt', tokens.refreshExpiresAt);

      return true;
    } catch (error) {
      console.error('Token refresh failed:', error);
      return false;
    }
  }, []);

  // Get current user info
  const getCurrentUser = useCallback(async (): Promise<User | null> => {
    try {
      const accessToken = localStorage.getItem('accessToken');
      if (!accessToken) {
        return null;
      }

      const response = await fetch('/api/auth/me', {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
        },
      });

      if (!response.ok) {
        if (response.status === 401) {
          // Try to refresh token
          const refreshed = await refreshToken();
          if (refreshed) {
            // Retry with new token
            const newToken = localStorage.getItem('accessToken');
            const retryResponse = await fetch('/api/auth/me', {
              headers: {
                'Authorization': `Bearer ${newToken}`,
              },
            });

            if (retryResponse.ok) {
              const data = await retryResponse.json();
              return data.user;
            }
          }
        }
        return null;
      }

      const data = await response.json();
      return data.user;
    } catch (error) {
      console.error('Get current user failed:', error);
      return null;
    }
  }, [refreshToken]);

  // Login function
  const login = useCallback(async (email: string, password: string): Promise<void> => {
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Login failed');
      }

      const { user: loggedInUser, tokens } = data;

      // Store tokens and user info
      localStorage.setItem('accessToken', tokens.accessToken);
      localStorage.setItem('refreshToken', tokens.refreshToken);
      localStorage.setItem('tokenExpiresAt', tokens.expiresAt);
      localStorage.setItem('refreshExpiresAt', tokens.refreshExpiresAt);
      localStorage.setItem('user', JSON.stringify(loggedInUser));

      setUser(loggedInUser);
      toast.success(`Welcome back, ${loggedInUser.email}!`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Login failed';
      toast.error(errorMessage);
      throw error;
    }
  }, []);

  // Logout function
  const logout = useCallback(async (allSessions: boolean = false): Promise<void> => {
    try {
      const accessToken = localStorage.getItem('accessToken');
      if (accessToken) {
        await fetch('/api/auth/logout', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ allSessions }),
        });
      }
    } catch (error) {
      console.error('Logout API call failed:', error);
    } finally {
      // Clear local storage regardless of API call success
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('tokenExpiresAt');
      localStorage.removeItem('refreshExpiresAt');
      localStorage.removeItem('user');
      
      setUser(null);
      toast.success('Logged out successfully');
      router.push('/login');
    }
  }, [router]);

  // Set up token refresh timer
  useEffect(() => {
    const setupTokenRefresh = () => {
      const tokenExpiresAt = localStorage.getItem('tokenExpiresAt');
      if (!tokenExpiresAt) return;

      const expiresAt = new Date(tokenExpiresAt).getTime();
      const now = Date.now();
      const timeUntilExpiry = expiresAt - now;

      // Refresh token 5 minutes before it expires
      const refreshTime = Math.max(timeUntilExpiry - 5 * 60 * 1000, 0);

      if (refreshTime > 0) {
        const timeoutId = setTimeout(async () => {
          const success = await refreshToken();
          if (success) {
            setupTokenRefresh(); // Set up next refresh
          } else {
            logout(); // Token refresh failed, logout user
          }
        }, refreshTime);

        return () => clearTimeout(timeoutId);
      }
    };

    return setupTokenRefresh();
  }, [refreshToken, logout]);

  // Initialize auth state
  useEffect(() => {
    const initializeAuth = async () => {
      setIsLoading(true);
      
      try {
        // Check if user data exists in localStorage
        const storedUser = localStorage.getItem('user');
        const accessToken = localStorage.getItem('accessToken');
        
        if (storedUser && accessToken) {
          // Verify token is still valid by fetching current user
          const currentUser = await getCurrentUser();
          if (currentUser) {
            setUser(currentUser);
            // Update stored user info if it changed
            localStorage.setItem('user', JSON.stringify(currentUser));
          } else {
            // Token is invalid, clear storage
            localStorage.removeItem('accessToken');
            localStorage.removeItem('refreshToken');
            localStorage.removeItem('tokenExpiresAt');
            localStorage.removeItem('refreshExpiresAt');
            localStorage.removeItem('user');
          }
        }
      } catch (error) {
        console.error('Auth initialization failed:', error);
      } finally {
        setIsLoading(false);
      }
    };

    initializeAuth();
  }, [getCurrentUser]);

  const contextValue: AuthContextType = {
    user,
    isLoading,
    isAuthenticated: !!user,
    login,
    logout,
    refreshToken,
    hasRole,
    hasPermission,
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}