// User-friendly error message mappings
export const ERROR_MESSAGES: Record<string, string> = {
  // Contract errors
  'InsufficientBalance': 'You don\'t have enough tokens to complete this transaction',
  'NotSupported': 'This collateral type is not supported',
  'WithdrawalsDisabled': 'Withdrawals are temporarily disabled. Please try again later',
  'NotAuthorized': 'You are not authorized to perform this action',
  'AmountTooLow': 'The amount is below the minimum threshold',
  'AmountTooHigh': 'The amount exceeds the maximum limit',
  'InsufficientLiquidity': 'There is not enough liquidity to process your withdrawal',
  'CollateralAlreadySupported': 'This collateral is already supported',
  'CollateralNotSupported': 'This collateral is not supported',
  'ZeroAddress': 'Invalid address provided',
  'ZeroAmount': 'Amount must be greater than zero',
  
  // Wallet errors
  'UserRejected': 'Transaction was cancelled',
  'UserRejectedRequest': 'You rejected the transaction request',
  'ChainMismatch': 'Please switch to the correct network',
  'NotConnected': 'Please connect your wallet first',
  
  // Network errors
  'NetworkError': 'Network error occurred. Please check your connection',
  'RateLimited': 'Too many requests. Please wait a moment and try again',
  'GasTooHigh': 'Gas price is too high. Consider waiting for lower fees',
  'NonceTooLow': 'Transaction nonce is too low',
  'ReplacementUnderpriced': 'Replacement transaction underpriced',
  
  // Generic errors
  'Unknown': 'An unexpected error occurred. Please try again',
  'Timeout': 'Transaction timed out. Please check your wallet',
};

export function getErrorMessage(error: any): string {
  if (!error) return ERROR_MESSAGES['Unknown'];
  
  // Check for specific error patterns
  const errorString = error.toString();
  
  // Check for revert reasons
  if (error.reason) {
    for (const [key, message] of Object.entries(ERROR_MESSAGES)) {
      if (error.reason.includes(key)) {
        return message;
      }
    }
    return error.reason;
  }
  
  // Check for error messages
  if (error.message) {
    for (const [key, message] of Object.entries(ERROR_MESSAGES)) {
      if (error.message.includes(key)) {
        return message;
      }
    }
    
    // Check for user rejection
    if (error.message.includes('User rejected') || error.message.includes('User denied')) {
      return ERROR_MESSAGES['UserRejected'];
    }
  }
  
  // Check error code
  if (error.code) {
    switch (error.code) {
      case 4001:
        return ERROR_MESSAGES['UserRejected'];
      case -32002:
        return 'Please check your wallet for pending requests';
      case -32603:
        return ERROR_MESSAGES['NetworkError'];
      default:
        break;
    }
  }
  
  // Default error message
  return ERROR_MESSAGES['Unknown'];
}

export function isUserRejection(error: any): boolean {
  if (!error) return false;
  
  return (
    error.code === 4001 ||
    error.message?.includes('User rejected') ||
    error.message?.includes('User denied') ||
    error.reason?.includes('UserRejected')
  );
}