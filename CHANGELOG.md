# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/ivan-podgurskiy/spdx_expression/compare/v0.1.0...HEAD
