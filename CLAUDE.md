# Fountfi Foundry Project Guide

## Build Commands
- Build: `forge build`
- Test (all): `forge test`
- Test (single): `forge test --match-test test_Increment`
- Test (verbose): `forge test -vvv`
- Format: `forge fmt`
- Gas snapshot: `forge snapshot`
- Deploy: `forge script script/SimpleRWADeploy.s.sol:SimpleRWADeployScript --rpc-url <url> --private-key <key>`

## Code Style Guidelines
- **Pragma**: Use `^0.8.13` or higher
- **Imports**: Named using `{Contract} from "path"` syntax
- **Formatting**: 4-space indentation, braces on same line as declarations
- **Types**: Always use explicit types (uint256 instead of uint)
- **Naming**: 
  - Contracts: PascalCase (tRWA, SimpleRWA)
  - Functions: camelCase (setNumber, updateNav)
  - Tests: prefix with `test_` or `testFuzz_`
- **Visibility**: Always declare explicitly (public, internal, private)
- **Error handling**: Use custom errors with revert or require statements
- **Documentation**: SPDX license identifier required for all files
- **Events**: Emit events for important state changes

## Protocol Overview
The Fountfi protocol enables tokenization of Real World Assets (RWA) with:
- Share-based accounting for RWA representation
- NAV (Net Asset Value) oracle integration
- KYC/AML compliance features
- Modular architecture for extensibility

Consult [Foundry Book](https://book.getfoundry.sh/) for more development details.