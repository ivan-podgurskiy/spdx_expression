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

Add `spdx_expression` to the dependencies in `mix.exs` after `0.1.0` is
published:

```elixir
def deps do
  [
    {:spdx_expression, "~> 0.1"}
  ]
end
```

The package requires Elixir 1.14 or later and OTP 25 or later.

## Quick Start

Canonicalize an expression:

```elixir
SpdxExpression.canonicalize("mit and (apache-2.0 or bsd-2-clause)")
#=> {:ok, "MIT AND (Apache-2.0 OR BSD-2-Clause)"}

SpdxExpression.canonicalize!("gpl-3.0-only with classpath-exception-2.0")
#=> "GPL-3.0-only WITH Classpath-exception-2.0"

SpdxExpression.valid?("MIT OR Apache-2.0")
#=> true
```

Errors identify the failed token and its zero-based byte offset:

```elixir
{:error, error} = SpdxExpression.canonicalize("MIT OR Unknown-License")
error.kind
#=> :unknown_license
error.offset
#=> 7
```

## Supported Expressions

The parser supports current SPDX 3.28.0 license and exception identifiers,
`AND`, `OR`, `WITH`, nested parentheses, accepted legacy `+` suffixes, and
local `LicenseRef-*` identifiers. Known identifiers and operators are
case-insensitive; output uses canonical identifier casing and uppercase
operators.

The `LicenseRef-` suffix may contain ASCII letters, digits, `.` and `-`.
External `DocumentRef-*` references are not supported. Deprecated identifiers
are rejected with a distinct error kind.

Inputs are limited to 65,536 bytes and 128 parenthesis levels.

## Standards Boundary

The package validates SPDX expression syntax and identifiers for package
metadata. It does not determine whether licenses are legally compatible or
acceptable under an organization's policy.

PEP 639 and the SPDX expression specification define the supported profile.
The package embeds SPDX License List 3.28.0; query it with:

```elixir
SpdxExpression.license_list_version()
#=> "3.28.0"
```

Python is not required to install, test normally, or run this library. A
pinned Python `packaging` release is used only by an optional development
compatibility check.

## API

- `canonicalize/1` returns `{:ok, canonical}` or a structured error.
- `canonicalize!/1` returns the canonical expression or raises that error.
- `valid?/1` returns a boolean for any Elixir term.
- `license_list_version/0` reports the embedded SPDX data version.

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

Regenerate the embedded identifier registry with:

```bash
mix run scripts/generate_spdx_data.exs
git diff --exit-code -- lib/spdx_expression/data.ex
```

See [SPDX_DATA.md](SPDX_DATA.md) for upstream URLs, checksums, counts, and
attribution. Ordinary API calls perform no network or filesystem I/O.

## License

MIT © Ivan Podgurskiy. See [LICENSE](LICENSE).
