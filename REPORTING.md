Hi Claude, help me think through this design decision.

As you can tell by reading the code, we need to report the fund's AUM in an on-chain manner. Ultimately, the end goal is that we should be able to implement the `totalAssets` function in a tRWA token in a way that is compliant with the ERC4626 spec.

In a ReportedStrategy, the way we get this value is:

1) A privileged address calls `AumOracleReporter#update` with the fund's total AUM
2)