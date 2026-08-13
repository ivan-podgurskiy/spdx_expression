# Releasing

Releases are performed from a clean `main` checkout whose commit matches
`origin/main`. Stop at the first failing command. Never create the release tag
until the repository is public, the exact commit has green CI, and Hex
authentication and the publish dry run both succeed.

## 1. Finalize the Release

1. Start from a clean, synchronized `main` checkout:

   ```bash
   git status --short
   git fetch origin main
   test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
   ```

2. Set the version in `mix.exs`.
3. Move completed entries from `Unreleased` to a dated version section in
   `CHANGELOG.md`.
4. Confirm README examples, SPDX version references, source links, and the
   compatibility documentation describe the release being built.

## 2. Run the Ordinary Quality Suite

```bash
mix deps.get
mix format --check-formatted
MIX_ENV=test mix do compile --warnings-as-errors + test --warnings-as-errors
mix test --cover --warnings-as-errors
mix credo --strict
mix dialyzer --format github
mix docs --warnings-as-errors
```

The coverage command must report 100% for `SpdxExpression.Tokenizer`,
`SpdxExpression.Parser`, `SpdxExpression.Registry`, and
`SpdxExpression.Canonicalizer`. Mix coverage is line-based; the acceptance,
unit, property, compatibility, boundary, and fuzz suites provide the explicit
behavior and branch evidence around that metric.

## 3. Verify Embedded SPDX Data

Regenerate the compile-time registry and confirm it is byte-for-byte current:

```bash
mix run scripts/generate_spdx_data.exs
git diff --exit-code -- lib/spdx_expression/data.ex
```

Compare the committed source hashes with `SPDX_DATA.md`:

```bash
shasum -a 256 priv/spdx/3.28.0/licenses.json priv/spdx/3.28.0/exceptions.json
```

Run the pinned compatibility oracle in an isolated Python environment:

```bash
python3 -m venv /tmp/spdx_expression_packaging_26
/tmp/spdx_expression_packaging_26/bin/pip install "packaging==26.0"
PATH="/tmp/spdx_expression_packaging_26/bin:$PATH" \
  MIX_ENV=dev mix run scripts/differential_check.exs
```

## 4. Run Release-Only Robustness Checks

Run the reproducible one-million-input campaign:

```bash
MIX_ENV=dev mix run scripts/fuzz.exs --runs 1000000 --seed 101,202,303
```

The runner mixes arbitrary binaries, grammar-shaped token streams, mutations
of valid expressions, and exact boundary cases. It checks both non-bang APIs,
canonicalization idempotence, result shapes, caught exits/errors/throws, and
atom-table stability. A failure prints the iteration, base64 input, and replay
budget. The release gate is zero failures and zero atoms added.

Run the representative performance guard separately:

```bash
MIX_ENV=dev mix run scripts/benchmark.exs --iterations 200000 --max-us 100.0
```

The benchmark performs 10,000 warmup calls and measures 200,000 calls in 20
batches. The 100 μs mean guard is deliberately generous across supported
development machines and remains outside ordinary CI to avoid noisy
shared-runner failures.

## 5. Inspect the Hex Artifact

Build and unpack the exact package, review its file list and metadata, then
compile the unpacked package in the production environment:

```bash
package_dir="$(mktemp -d "${TMPDIR:-/tmp}/spdx_expression.XXXXXX")"
mix hex.build --unpack --output "$package_dir"
sed -n '1,240p' "$package_dir/hex_metadata.config"
(cd "$package_dir" && MIX_ENV=prod mix compile --warnings-as-errors)
```

The metadata must show `requirements: []`. The artifact must contain runtime
source, README, CHANGELOG, LICENSE, compatibility documentation, and SPDX data
attribution. It must not contain tests, scripts, raw SPDX JSON, development
dependencies, PRDs, or superpowers documents.

## 6. Confirm Remote Readiness

1. Review the final diff, create the release commit from only the intentional
   package and release files, and confirm the worktree is clean. Never include
   PRDs or superpowers documents in the commit.
2. Push the release commit to `main` and confirm its SHA matches `origin/main`.
3. Wait for every Linux, macOS, and Windows job to pass on that exact SHA.
4. Make the GitHub repository public and verify the source URL is anonymously
   readable.
5. Confirm the package name remains available on Hex.
6. Authenticate Hex and run its official dry run:

   ```bash
   mix hex.user whoami
   mix hex.publish --dry-run
   ```

Check first-release name availability separately with
`mix hex.info spdx_expression`: it must report that no package exists. This
expected result has a non-zero exit status, so it does not belong in the
fail-fast command block. If authentication or the dry run fails, stop before
tagging.

## 7. Tag and Publish

Create the tag only after all previous gates pass:

```bash
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
mix hex.publish
```

Create the matching GitHub release from the pushed tag:

```bash
gh release create v0.1.0 --verify-tag --title "v0.1.0" --generate-notes
```

## 8. Verify the Published Release

Confirm all of the following before announcing the release:

- `https://hex.pm/packages/spdx_expression` shows version `0.1.0`, MIT, the
  expected links, and no runtime dependencies.
- `https://hexdocs.pm/spdx_expression/0.1.0` loads without missing pages and
  its source links reach the public `v0.1.0` GitHub tag.
- `mix hex.info spdx_expression 0.1.0` reports the published metadata.
- GitHub shows the public `v0.1.0` tag and release.
- Set the GitHub repository homepage to
  `https://hex.pm/packages/spdx_expression`.

If a critical problem is discovered after publication, Hex allows the first
package release to be reverted or replaced within 24 hours. Investigate the
problem before using `mix hex.publish --revert 0.1.0`; do not silently replace
a release after that window.
