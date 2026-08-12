# Releasing

Run the complete local quality suite from [CONTRIBUTING.md](CONTRIBUTING.md)
before the release-only checks below.

## Hostile-Input Campaign

Run the reproducible one-million-input campaign:

```bash
MIX_ENV=dev mix run scripts/fuzz.exs --runs 1000000 --seed 101,202,303
```

The runner mixes arbitrary binaries, grammar-shaped token streams, mutations
of valid expressions, and exact boundary cases. It checks both non-bang APIs,
canonicalization idempotence, result shapes, caught exits/errors/throws, and
atom-table stability. A failure prints the iteration, base64 input, and replay
budget. It is intentionally excluded from ordinary CI and the Hex package.

Recorded baseline on 2026-08-12: 1,000,000 inputs completed in 7,764 ms with
zero crashes, invariant failures, or new atoms on Darwin 25.6.0 arm64, OTP 27,
and Elixir 1.18.3 using seed `101,202,303`. Timing is informational; the zero
failure and zero-atom results are the release gates.

## Performance Guard

Run the representative performance guard separately:

```bash
MIX_ENV=dev mix run scripts/benchmark.exs --iterations 200000 --max-us 100.0
```

The benchmark performs 10,000 warmup calls and measures 200,000 calls in 20
batches. On the same 2026-08-12 environment, the expression
`mit and (apache-2.0 or bsd-2-clause)` averaged 1.807 μs per call, with batch
means from 1.756 μs to 1.871 μs. The 100 μs mean guard is deliberately generous
across supported development machines; timing checks remain outside ordinary
CI to avoid noisy shared-runner failures.
