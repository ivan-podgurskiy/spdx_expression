# SPDX License List Data

`spdx_expression` embeds identifiers from SPDX License List `3.28.0`, released
on 2026-02-20. Runtime lookup data is generated from the two upstream summary
files below.

| File | Entries | SHA-256 |
| --- | ---: | --- |
| [`licenses.json`](https://raw.githubusercontent.com/spdx/license-list-data/v3.28.0/json/licenses.json) | 727 (695 active, 32 deprecated) | `f728c534d8bd1044fc515a2ddb2292be99559021d830bfa3281be0bcd36302ee` |
| [`exceptions.json`](https://raw.githubusercontent.com/spdx/license-list-data/v3.28.0/json/exceptions.json) | 84 (83 active, 1 deprecated) | `bd145bb558f44432fcd6f0d7e956ed0124dff72af7641a7cfcb1b557dc390a5b` |

The files are stored byte-for-byte under `priv/spdx/3.28.0/`. They are source
inputs and are not included in the Hex package.

Regenerate the compile-time lookup module with:

```bash
mix run scripts/generate_spdx_data.exs
```

The SPDX License List data repository is published at
<https://github.com/spdx/license-list-data>. See that repository and its source
project for the applicable data licensing and attribution information.
