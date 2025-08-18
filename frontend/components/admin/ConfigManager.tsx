'use client';

import { useState } from 'react';
import { DeploymentRegistry } from '@/lib/deployments/registry';
import { DeploymentValidator } from '@/lib/deployments/validator';
import { X, Download, Upload, Copy, CheckCircle, AlertCircle, FileJson } from 'lucide-react';
import { toast } from 'react-hot-toast';

interface ConfigManagerProps {
  registry: DeploymentRegistry;
  onClose: () => void;
}

export function ConfigManager({ registry, onClose }: ConfigManagerProps) {
  const [importData, setImportData] = useState('');
  const [exportData, setExportData] = useState('');
  const [showExport, setShowExport] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);

  const handleExport = () => {
    const config = registry.exportConfig();
    setExportData(config);
    setShowExport(true);
  };

  const handleCopyExport = () => {
    navigator.clipboard.writeText(exportData);
    toast.success('Configuration copied to clipboard');
  };

  const handleDownloadExport = () => {
    const blob = new Blob([exportData], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sova-deployments-${Date.now()}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    toast.success('Configuration downloaded');
  };

  const handleImport = () => {
    setErrors([]);
    
    try {
      // Parse JSON
      const data = JSON.parse(importData);
      
      // Validate import data
      const validation = DeploymentValidator.validateImportData(data);
      if (!validation.valid) {
        setErrors(validation.errors);
        return;
      }
      
      // Import config
      registry.importConfig(importData);
      toast.success('Configuration imported successfully');
      onClose();
    } catch (error) {
      setErrors([`Invalid JSON: ${error instanceof Error ? error.message : 'Unknown error'}`]);
    }
  };

  const handleFileImport = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
      const content = e.target?.result as string;
      setImportData(content);
      toast.success('File loaded. Click Import to apply.');
    };
    reader.onerror = () => {
      toast.error('Failed to read file');
    };
    reader.readAsText(file);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      
      {/* Modal */}
      <div className="relative glass-card rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="p-6 border-b border-white/10">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <FileJson className="w-6 h-6 text-mint-400" />
              <h2 className="text-xl font-semibold text-white">
                Import/Export Configuration
              </h2>
            </div>
            <button
              onClick={onClose}
              className="p-2 hover:bg-white/10 rounded-lg transition-colors"
            >
              <X className="w-5 h-5 text-white/60" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto max-h-[calc(90vh-200px)]">
          {!showExport ? (
            <>
              {/* Import Section */}
              <div className="space-y-4 mb-8">
                <h3 className="text-white/87 font-medium flex items-center space-x-2">
                  <Upload className="w-4 h-4" />
                  <span>Import Configuration</span>
                </h3>
                
                <div className="glass-card rounded-lg p-4">
                  <p className="text-white/60 text-sm mb-4">
                    Import deployment configurations from a JSON file or paste the configuration below.
                  </p>
                  
                  {/* File Upload */}
                  <div className="mb-4">
                    <label className="glass-button rounded-lg px-4 py-2 cursor-pointer inline-flex items-center space-x-2">
                      <Upload className="w-4 h-4" />
                      <span>Choose File</span>
                      <input
                        type="file"
                        accept=".json"
                        onChange={handleFileImport}
                        className="hidden"
                      />
                    </label>
                  </div>
                  
                  {/* Text Area */}
                  <textarea
                    value={importData}
                    onChange={(e) => setImportData(e.target.value)}
                    placeholder="Paste configuration JSON here..."
                    className="w-full h-64 glass-input rounded-lg p-3 font-mono text-sm"
                  />
                  
                  {/* Validation Errors */}
                  {errors.length > 0 && (
                    <div className="mt-4 glass-card rounded-lg p-3 border-rose-400/30 bg-rose-400/5">
                      <div className="flex items-center space-x-2 text-rose-400 mb-2">
                        <AlertCircle className="w-4 h-4" />
                        <span className="font-medium text-sm">Import Errors</span>
                      </div>
                      <ul className="space-y-1">
                        {errors.map((error, i) => (
                          <li key={i} className="text-white/60 text-xs">• {error}</li>
                        ))}
                      </ul>
                    </div>
                  )}
                  
                  <div className="mt-4 flex justify-end">
                    <button
                      onClick={handleImport}
                      disabled={!importData}
                      className="bg-gradient-primary text-white rounded-lg px-4 py-2 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      Import Configuration
                    </button>
                  </div>
                </div>
              </div>

              {/* Export Section */}
              <div className="space-y-4">
                <h3 className="text-white/87 font-medium flex items-center space-x-2">
                  <Download className="w-4 h-4" />
                  <span>Export Configuration</span>
                </h3>
                
                <div className="glass-card rounded-lg p-4">
                  <p className="text-white/60 text-sm mb-4">
                    Export all deployment configurations to share or backup.
                  </p>
                  
                  <button
                    onClick={handleExport}
                    className="glass-button rounded-lg px-4 py-2 flex items-center space-x-2"
                  >
                    <Download className="w-4 h-4" />
                    <span>Generate Export</span>
                  </button>
                </div>
              </div>
            </>
          ) : (
            /* Export View */
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-white/87 font-medium flex items-center space-x-2">
                  <CheckCircle className="w-4 h-4 text-green-400" />
                  <span>Export Ready</span>
                </h3>
                <button
                  onClick={() => setShowExport(false)}
                  className="text-white/60 hover:text-white/87 text-sm"
                >
                  ← Back
                </button>
              </div>
              
              <div className="glass-card rounded-lg p-4">
                <p className="text-white/60 text-sm mb-4">
                  Your configuration has been exported. You can copy it or download as a file.
                </p>
                
                <div className="bg-zinc-900/50 rounded-lg p-3 mb-4">
                  <pre className="text-white/87 text-xs font-mono overflow-x-auto">
                    {exportData}
                  </pre>
                </div>
                
                <div className="flex items-center space-x-3">
                  <button
                    onClick={handleCopyExport}
                    className="glass-button rounded-lg px-4 py-2 flex items-center space-x-2"
                  >
                    <Copy className="w-4 h-4" />
                    <span>Copy to Clipboard</span>
                  </button>
                  
                  <button
                    onClick={handleDownloadExport}
                    className="bg-gradient-primary text-white rounded-lg px-4 py-2 font-medium flex items-center space-x-2"
                  >
                    <Download className="w-4 h-4" />
                    <span>Download JSON</span>
                  </button>
                </div>
              </div>
              
              {/* Share Options */}
              <div className="glass-card rounded-lg p-4">
                <h4 className="text-white/87 font-medium mb-3">Sharing Options</h4>
                <div className="space-y-2 text-sm">
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-green-400 rounded-full" />
                    <span className="text-white/60">
                      Save to IPFS for decentralized sharing (coming soon)
                    </span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-blue-400 rounded-full" />
                    <span className="text-white/60">
                      Share via encrypted link (coming soon)
                    </span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-mint-400 rounded-full" />
                    <span className="text-white/60">
                      Sync with team members (coming soon)
                    </span>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-white/10 flex items-center justify-between">
          <div className="text-white/40 text-xs">
            Configuration format v1.0.0
          </div>
          <button
            onClick={onClose}
            className="glass-button rounded-lg px-4 py-2"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}