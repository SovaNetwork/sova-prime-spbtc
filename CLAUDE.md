# Fountfi Foundry Project Guide

## Build Commands
- Build: `forge build`
- Test (all): `forge test`
- Test (single): `forge test --match-test test_Increment`
- Test (verbose): `forge test -vvv`
- Format: `forge fmt`
- Gas snapshot: `forge snapshot`
- Deploy: `forge script script/RegistryDeploy.s.sol:RegistryDeployScript --rpc-url <url> --private-key <key>`

## Code Style Guidelines
- **Pragma**: Use `0.8.25` or higher
- **Imports**: Named using `{Contract} from "path"` syntax
- **Formatting**: 4-space indentation, braces on same line as declarations
- **Types**: Always use explicit types (uint256 instead of uint)
- **Naming**:
  - Contracts: PascalCase (tRWA, SimpleRWA)
  - Functions: camelCase (setNumber, updateNav)
  - Tests: prefix with `test_` or `testFuzz_`
  - Deploy scripts: suffix with `.s.sol`
- **Visibility**: Always declare explicitly (public, internal, private)
- **Error handling**: Use custom errors with revert or require statements
- **Documentation**: SPDX license identifier required for all files
- **Events**: Emit events for important state changes
- **Commits**: Single-line, brief commits explaining code changes.

## Guidelines for Claude

- When fixing tests, try to only change the test files. If it's necessary to update the smart contracts, stop, explain why, and confirm before proceeding.
- If a prompt mentions that code was changed, always re-read the file.
- Commit often, so that we always have checkpoints to return to.

## Protocol Overview
The Fountfi protocol enables tokenization of Real World Assets (RWA) with:
- Strategy-centric architecture where each strategy deploys its own token
- Share-based accounting for RWA representation
- NAV (Net Asset Value) oracle integration
- KYC/AML compliance features
- Modular architecture for extensibility

## Architecture
- **Registry**: Central registry for strategies, rules, assets, and reporters
- **Strategy**: Components that manage assets and deploy their share tokens
- **sToken**: Each strategy's tRWA token (share token)
- **Rules**: Components enforcing compliance requirements
- **Reporters**: Oracle contracts providing asset valuation
- **Managers**: Handle subscriptiona nd withdrawal logic (investor caps, lockups, redemption queues)

## Implementation Notes
- Each strategy deploys its own token during initialization
- Strategy implementations are registered in the registry and cloned using the Clones pattern.
- Registry enforces proper rules, assets, and reporters for deployment

Consult [Foundry Book](https://book.getfoundry.sh/) for more development details.

## Next Steps
- Implement full manager functionality for subscriptios and redemptions.
- Implement complete withdrawal functionality in tRWA token (fix the TODO in the withdraw function)
- Create a RedemptionQueue contract for managing pending withdrawals with time delays
- Develop additional rule modules:
  - InvestorLimit rule to enforce maximum limits per investor
  - LockupPeriodRule to enforce minimum holding periods
- Consider implications of inflation attacks and other MEV vectors
- Add invariant testing using Foundry's property-based testing
- Create comprehensive documentation and deployment guides