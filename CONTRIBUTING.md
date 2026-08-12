# Contributing

## Local Checks

Install dependencies and run the complete local quality suite:

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
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

CI compiles and runs the complete ordinary test suite on Ubuntu with Elixir
1.14/OTP 25 and Elixir 1.18/OTP 27, plus macOS and Windows with Elixir 1.18/OTP
27. The latest Ubuntu lane additionally enforces formatting,
warnings-as-errors, reproducible SPDX generation, strict Credo, Dialyzer,
warning-free ExDoc, and Hex artifact construction.

Before publishing a release, also run the expensive checks in
[RELEASING.md](RELEASING.md).
