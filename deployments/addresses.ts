/**
 * BTC Vault Contract Addresses - Base Sepolia
 * Deployed: 2025-09-30
 */

export const BASE_SEPOLIA_ADDRESSES = {
  // Main contracts
  btcVaultStrategy: '0x9f03Dd454E2e497ec69961bF9d99F848Fe052A59',
  btcVaultToken: '0xF7E3De8a17934BAA8CF7A89E9925660Bd830d904', // spBTC
  priceOracleReporter: '0x077b4f3e1E8dce34318C977c78B9569a97D9d938',

  // Libraries (internal use)
  collateralManagementLib: '0xe978b41c0aBba108145C61579ac3Ab480a36290C',
  collateralViewLib: '0xBf204Af2F7eE9540BEa1E5396973B82E82F0c008',

  // Supported collateral tokens
  collateral: {
    sovaBTC: '0x26319Bcf5457b7D95b4115B89CaFDc1484E57Eae',
    wBTC: '0xa87a96DBF51B950F283AFDFFd242170C40D90502',
    cbBTC: '0x6F6ACaA552936F6545D9b29757876E20d5e3fc93',
  },

  // Role manager
  roleManager: '0x15502fC5e872c8B22BA6dD5e01A7A5bd4f9A3d72',
} as const;

export const CHAIN_ID = 84532; // Base Sepolia

export const DECIMALS = {
  BTC: 8,    // sovaBTC, WBTC, cbBTC
  SHARES: 18, // spBTC shares
  NAV: 18,    // Price per share
} as const;

export const MIN_DEPOSIT = 1000n; // 1000 satoshis (0.00001 BTC)

export const EXPLORER_URLS = {
  btcVaultStrategy: 'https://sepolia.basescan.org/address/0x9f03Dd454E2e497ec69961bF9d99F848Fe052A59',
  btcVaultToken: 'https://sepolia.basescan.org/address/0xF7E3De8a17934BAA8CF7A89E9925660Bd830d904',
  priceOracleReporter: 'https://sepolia.basescan.org/address/0x077b4f3e1E8dce34318C977c78B9569a97D9d938',
} as const;
