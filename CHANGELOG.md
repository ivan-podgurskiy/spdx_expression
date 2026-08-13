# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-08-13

### Added

- `SpdxExpression.canonicalize/1` and `canonicalize!/1` for PEP 639-compatible
  SPDX license expressions.
- `SpdxExpression.valid?/1` for total boolean validation of ordinary input.
- Structured errors with stable kinds, original tokens, and zero-based byte
  offsets.
- SPDX `AND`, `OR`, `WITH`, parentheses, legacy `+`, and local `LicenseRef-*`
  support.
- Reproducibly generated SPDX License List 3.28.0 data and
  `license_list_version/0`.
- Explicit size and parenthesis-depth limits for untrusted input.
- A committed 72-case PEP 639 and `packaging==26.0` compatibility corpus plus
  an optional pinned differential-check script.
- Deterministic property tests for canonicalization, private AST round trips,
  exact registry spelling, arbitrary binaries, and dynamic-atom safety.
- Exact hostile-input boundary coverage and a reproducible dev-only
  one-million-input fuzz runner.
- A dependency-free representative canonicalization benchmark with an
  explicitly invoked 100-microsecond regression guard.
- Continuous integration across Linux, macOS, and Windows, including Linux
  coverage for Elixir/OTP generations from 1.14/25 through 1.20/29 and an
  Elixir 1.20/OTP 29 quality lane for core coverage, formatting, warnings,
  SPDX regeneration, Credo, Dialyzer, ExDoc, and Hex artifact checks.

### Compatibility

- Deprecated SPDX identifiers are rejected with category-specific errors even
  though `packaging==26.0` canonicalizes them.
- SPDX License List 3.28.0 identifiers are accepted even when absent from the
  oracle's embedded SPDX 3.27.0 data.
- Parenthesized or compound `WITH` operands and chained `WITH` are rejected
  even though the oracle accepts them.
- Empty `LicenseRef-` suffixes and Unicode whitespace are rejected even though
  the oracle accepts them.
- Python's single validation exception is represented as stable structured
  errors, and Elixir-specific byte-size, nesting, malformed-binary, and input
  type boundaries are enforced outside the differential corpus.

[Unreleased]: https://github.com/ivan-podgurskiy/spdx_expression/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ivan-podgurskiy/spdx_expression/releases/tag/v0.1.0
