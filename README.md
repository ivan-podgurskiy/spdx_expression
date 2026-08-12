# SpdxExpression

[![CI](https://github.com/ivan-podgurskiy/spdx_expression/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/spdx_expression/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Validate and canonicalize PEP 639-compatible SPDX license expressions in
Elixir, without runtime dependencies.

## Purpose

`SpdxExpression` turns untrusted license-expression text into a validated,
deterministically formatted SPDX expression or a structured error. It embeds a
pinned SPDX License List and performs no runtime network or filesystem access.

## Installation

The package is not published while `0.1.0` is under development. Use the Git
repository from a trusted revision during development.

## Quick Start

The first working slice currently exposes the embedded data version:

```elixir
SpdxExpression.license_list_version()
#=> "3.28.0"
```

Canonicalization APIs will be added during this slice.

## Standards Boundary

The package validates SPDX expression syntax and identifiers for package
metadata. It does not determine whether licenses are legally compatible or
acceptable under an organization's policy.

## Development

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer --format github
mix docs
mix hex.build
```

## License

MIT © Ivan Podgurskiy. See [LICENSE](LICENSE).
