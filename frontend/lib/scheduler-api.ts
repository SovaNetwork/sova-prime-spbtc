export class SchedulerAPI {
  private baseUrl: string;

  constructor() {
    this.baseUrl = process.env.NEXT_PUBLIC_SCHEDULER_URL || 'http://localhost:3001';
  }

  private async fetchAPI(endpoint: string, options?: RequestInit) {
    try {
      const response = await fetch(`${this.baseUrl}${endpoint}`, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options?.headers,
        },
      });

      if (!response.ok) {
        throw new Error(`API call failed: ${response.status} ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error(`SchedulerAPI error for ${endpoint}:`, error);
      throw error;
    }
  }

  async getHealth() {
    return this.fetchAPI('/health');
  }

  async getStatus() {
    return this.fetchAPI('/status');
  }

  async triggerMetricsCollection() {
    return this.fetchAPI('/manual/metrics', {
      method: 'POST',
    });
  }

  async triggerCollateralsSync() {
    return this.fetchAPI('/manual/collaterals', {
      method: 'POST',
    });
  }

  async triggerDailySummary() {
    return this.fetchAPI('/manual/daily-summary', {
      method: 'POST',
    });
  }
}

// Create a singleton instance
export const schedulerAPI = new SchedulerAPI();

// React hooks for scheduler API
import { useState, useEffect } from 'react';

export function useSchedulerHealth() {
  const [health, setHealth] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const fetchHealth = async () => {
      try {
        setLoading(true);
        const data = await schedulerAPI.getHealth();
        setHealth(data);
        setError(null);
      } catch (err) {
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchHealth();
    const interval = setInterval(fetchHealth, 30000); // Check every 30 seconds

    return () => clearInterval(interval);
  }, []);

  return { health, loading, error };
}

export function useSchedulerStatus() {
  const [status, setStatus] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const refetch = async () => {
    try {
      setLoading(true);
      const data = await schedulerAPI.getStatus();
      setStatus(data);
      setError(null);
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refetch();
    const interval = setInterval(refetch, 60000); // Update every minute

    return () => clearInterval(interval);
  }, []);

  return { status, loading, error, refetch };
}

export function useSchedulerTriggers() {
  const [triggering, setTriggering] = useState<string | null>(null);
  const [error, setError] = useState<Error | null>(null);

  const triggerJob = async (jobType: 'metrics' | 'collaterals' | 'daily-summary') => {
    try {
      setTriggering(jobType);
      setError(null);

      let result;
      switch (jobType) {
        case 'metrics':
          result = await schedulerAPI.triggerMetricsCollection();
          break;
        case 'collaterals':
          result = await schedulerAPI.triggerCollateralsSync();
          break;
        case 'daily-summary':
          result = await schedulerAPI.triggerDailySummary();
          break;
      }

      return result;
    } catch (err) {
      setError(err as Error);
      throw err;
    } finally {
      setTriggering(null);
    }
  };

  return {
    triggerJob,
    triggering,
    error,
  };
}