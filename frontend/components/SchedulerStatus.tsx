'use client';

import { useSchedulerHealth, useSchedulerStatus, useSchedulerTriggers } from '@/lib/scheduler-api';
import { ActivityIcon, CheckCircleIcon, XCircleIcon, ClockIcon, PlayIcon } from 'lucide-react';
import toast from 'react-hot-toast';

export default function SchedulerStatus() {
  const { health, loading: healthLoading, error: healthError } = useSchedulerHealth();
  const { status, loading: statusLoading, error: statusError, refetch } = useSchedulerStatus();
  const { triggerJob, triggering } = useSchedulerTriggers();

  const handleTrigger = async (jobType: 'metrics' | 'collaterals' | 'daily-summary') => {
    try {
      await triggerJob(jobType);
      toast.success(`${jobType} job triggered successfully`);
      setTimeout(refetch, 2000); // Refresh status after 2 seconds
    } catch (err) {
      toast.error(`Failed to trigger ${jobType} job`);
    }
  };

  const isHealthy = health?.status === 'healthy';
  const loading = healthLoading || statusLoading;

  return (
    <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10 p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-xl font-semibold text-white">Scheduler Service</h3>
        <div className="flex items-center gap-2">
          {healthError || statusError ? (
            <XCircleIcon className="w-5 h-5 text-red-400" />
          ) : isHealthy ? (
            <CheckCircleIcon className="w-5 h-5 text-green-400" />
          ) : (
            <XCircleIcon className="w-5 h-5 text-yellow-400" />
          )}
          <span className={`text-sm ${
            healthError || statusError ? 'text-red-400' : 
            isHealthy ? 'text-green-400' : 'text-yellow-400'
          }`}>
            {healthError || statusError ? 'Error' : 
             isHealthy ? 'Healthy' : 'Degraded'}
          </span>
        </div>
      </div>

      {loading ? (
        <div className="space-y-3">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="animate-pulse">
              <div className="h-20 bg-white/5 rounded-lg"></div>
            </div>
          ))}
        </div>
      ) : (
        <>
          {/* Service Info */}
          {health && (
            <div className="mb-6 p-4 bg-white/5 rounded-lg">
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-gray-400">Status:</span>
                  <span className="ml-2 text-white">{health.status}</span>
                </div>
                <div>
                  <span className="text-gray-400">Uptime:</span>
                  <span className="ml-2 text-white">{health.uptime || 'N/A'}</span>
                </div>
                {health.database && (
                  <div>
                    <span className="text-gray-400">Database:</span>
                    <span className="ml-2 text-white">
                      {health.database.connected ? 'Connected' : 'Disconnected'}
                    </span>
                  </div>
                )}
                {health.lastCheck && (
                  <div>
                    <span className="text-gray-400">Last Check:</span>
                    <span className="ml-2 text-white">
                      {new Date(health.lastCheck).toLocaleTimeString()}
                    </span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Job Status */}
          {status?.jobs && (
            <div className="space-y-3">
              <h4 className="text-sm font-medium text-gray-400 uppercase tracking-wider">
                Scheduled Jobs
              </h4>
              
              {Object.entries(status.jobs).map(([jobName, jobInfo]: [string, any]) => (
                <div key={jobName} className="p-4 bg-white/5 rounded-lg">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <ActivityIcon className="w-4 h-4 text-violet-400" />
                      <span className="text-white font-medium capitalize">
                        {jobName.replace(/([A-Z])/g, ' $1').trim()}
                      </span>
                    </div>
                    <button
                      onClick={() => handleTrigger(jobName as any)}
                      disabled={triggering === jobName}
                      className="px-3 py-1 bg-violet-500/20 hover:bg-violet-500/30 text-violet-400 rounded-lg text-sm flex items-center gap-1 transition-colors disabled:opacity-50"
                    >
                      <PlayIcon className="w-3 h-3" />
                      {triggering === jobName ? 'Running...' : 'Run Now'}
                    </button>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-2 text-sm">
                    <div className="flex items-center gap-1 text-gray-400">
                      <ClockIcon className="w-3 h-3" />
                      Schedule: {jobInfo.schedule || 'Not set'}
                    </div>
                    {jobInfo.lastRun && (
                      <div className="text-gray-400">
                        Last run: {new Date(jobInfo.lastRun).toLocaleTimeString()}
                      </div>
                    )}
                    {jobInfo.nextRun && (
                      <div className="text-gray-400">
                        Next run: {new Date(jobInfo.nextRun).toLocaleTimeString()}
                      </div>
                    )}
                    {jobInfo.status && (
                      <div className="text-gray-400">
                        Status: <span className={
                          jobInfo.status === 'success' ? 'text-green-400' :
                          jobInfo.status === 'error' ? 'text-red-400' :
                          'text-yellow-400'
                        }>{jobInfo.status}</span>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Manual Triggers for Admin */}
          <div className="mt-6 pt-6 border-t border-white/10">
            <h4 className="text-sm font-medium text-gray-400 uppercase tracking-wider mb-3">
              Manual Controls (Admin Only)
            </h4>
            <div className="flex gap-2">
              <button
                onClick={() => handleTrigger('metrics')}
                disabled={triggering === 'metrics'}
                className="px-4 py-2 bg-violet-500/20 hover:bg-violet-500/30 text-violet-400 rounded-lg text-sm transition-colors disabled:opacity-50"
              >
                Collect Metrics
              </button>
              <button
                onClick={() => handleTrigger('collaterals')}
                disabled={triggering === 'collaterals'}
                className="px-4 py-2 bg-violet-500/20 hover:bg-violet-500/30 text-violet-400 rounded-lg text-sm transition-colors disabled:opacity-50"
              >
                Sync Collaterals
              </button>
              <button
                onClick={() => handleTrigger('daily-summary')}
                disabled={triggering === 'daily-summary'}
                className="px-4 py-2 bg-violet-500/20 hover:bg-violet-500/30 text-violet-400 rounded-lg text-sm transition-colors disabled:opacity-50"
              >
                Generate Summary
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}