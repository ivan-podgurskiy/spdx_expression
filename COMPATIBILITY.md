# Compatibility

`SpdxExpression` follows the license-expression profile introduced by
[PEP 639](https://peps.python.org/pep-0639/#spdx-license-expression-syntax)
and the compatible SPDX license-expression grammar it references. License and
exception identifiers come from the pinned SPDX License List 3.28.0 data
documented in [SPDX_DATA.md](SPDX_DATA.md).

Python [`packaging==26.0`](https://github.com/pypa/packaging/tree/26.0) at
commit `3b77a26f5a27473ad3b08194d773f325d018a2d0` is a development oracle, not a
normative source. That release embeds SPDX License List 3.27.0. Python is not a
runtime dependency and is not required for an ordinary `mix test` run.

## Committed corpus

`test/fixtures/license_expression_compatibility.json` contains 72
language-neutral cases ported from PEP 639, the `packaging 26.0`
license-expression fixtures, and package-profile boundaries. Each case stores
the expected project result and the expected oracle result. ExUnit reads these
committed expectations directly, without starting Python.

To verify both result sets against an installed oracle:

```bash
python3 -m pip install "packaging==26.0"
mix run scripts/differential_check.exs
```

The script skips cleanly if Python or `packaging` is absent and fails when a
different `packaging` version is installed. It is intentionally excluded from
ordinary CI and the Hex package.

After intentionally changing project behavior or the pinned oracle, refresh
the stored outcomes explicitly, review the resulting diff, and run the tests:

```bash
mix run scripts/differential_check.exs --update
mix test
```

Changing the pinned oracle requires reviewing every changed corpus result and
recording the compatibility impact in the changelog.

## Intentional oracle differences

Every result difference has a stable label in the corpus and a named ExUnit
regression test.

- `deprecated_identifiers`: `packaging 26.0` canonicalizes deprecated SPDX
  identifiers. This package rejects them with `:deprecated_license` or
  `:deprecated_exception`. PEP 639 permits tools to reject deprecated
  identifiers, and the strict result is part of this package's API contract.
- `spdx_data_version`: this package recognizes current identifiers added in
  SPDX 3.28.0 that the oracle's embedded SPDX 3.27.0 data does not know.
- `with_operand_validation`: the SPDX grammar permits `WITH` only after a
  simple license operand and permits only one exception. The oracle also
  accepts parenthesized or compound left operands and chained `WITH`; this
  package rejects them with `:invalid_with_operand`.
- `empty_license_ref`: PEP 639 requires one or more valid characters after
  `LicenseRef-`. The oracle accepts an empty suffix; this package rejects it
  with `:invalid_license_ref`.
- `unicode_whitespace`: the oracle relies on Python's Unicode-aware
  whitespace splitting. This package deliberately recognizes only the six
  ASCII whitespace bytes and rejects other bytes as `:invalid_character`.

Invalid expressions are otherwise compared by accepted/error status because
the Python API exposes one exception class while this package returns stable,
structured error kinds, original tokens, and zero-based byte offsets.

## Elixir-specific robustness boundary

Some public API behavior has no equivalent Python `str` input and therefore is
covered by native tests rather than the differential corpus:

- non-binary Elixir terms return `:invalid_type`;
- malformed UTF-8 binaries return structured errors rather than raising;
- input is limited to 65,536 bytes;
- parenthesis nesting is limited to 128 levels;
- only `canonicalize!/1` intentionally raises validation errors.

These limits prevent untrusted metadata from consuming unbounded parser
resources. They do not change successful canonicalization inside the supported
profile.
