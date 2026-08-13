# Contributing

## Local Checks

Install dependencies and run the complete local quality suite:

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test --warnings-as-errors
mix test --cover --warnings-as-errors
mix credo --strict
mix dialyzer --format github
mix docs --warnings-as-errors
mix hex.build
```

## Embedded SPDX Data

Regenerate the embedded identifier registry and confirm that the committed
output is current:

```bash
mix run scripts/generate_spdx_data.exs
git diff --exit-code -- lib/spdx_expression/data.ex
```

## PEP 639 Compatibility Oracle

The optional compatibility check uses an isolated Python environment with the
exact pinned `packaging` release. Python is not required to install, test
normally, or run the Elixir package.

```bash
python3 -m pip install "packaging==26.0"
mix run scripts/differential_check.exs
```

After an intentional behavior or oracle change, refresh the committed outcomes
with `mix run scripts/differential_check.exs --update`, review the diff, and run
the full test suite. The script is not part of ordinary CI or the Hex package.

## Continuous Integration

CI compiles and runs the complete ordinary test suite on Ubuntu for the
Elixir/OTP generations 1.14/25, 1.17/26, 1.18/27, 1.19/28, and 1.20/29. It
also tests Elixir 1.20/OTP 29 on macOS and Windows. The current Ubuntu lane
additionally enforces 100% line coverage for the tokenizer, parser, registry,
and canonicalizer, plus formatting, warnings-as-errors, reproducible SPDX
generation, strict Credo, Dialyzer, warning-free ExDoc, and Hex artifact
construction.

Before publishing a release, also run the expensive checks in
[RELEASING.md](RELEASING.md).
