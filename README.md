# pacto-bot-templates

Versioned templates for `pacto-bot-admin` scaffolding.

This repository hosts the templates used by the [`pacto-bot-api`](https://github.com/covenant-gov/pacto-bot-api) admin CLI to generate bot handler projects. Each top-level directory is a [`cargo-generate`](https://cargo-generate.github.io/cargo-generate/) template with its own `manifest.toml` declaring compatibility requirements and protected files.

## Layout

```text
python-llm/
  cargo-generate.toml  # cargo-generate placeholder definitions
  manifest.toml        # compatibility ranges and protected files
  bot/                 # files that land under bots/<bot-id>/
  project/             # files that land at the project root
```

## Available templates

| Directory | Language | Kind | Description |
|-----------|----------|------|-------------|
| `python-llm` | Python | llm | General-purpose Python LLM bot handler |

## Template manifest format

Each template directory contains a `manifest.toml` that describes the template to the admin CLI and declares which versions of the surrounding ecosystem it is compatible with.

```toml
manifest_version = 1
language = "python"
kind = "llm"
description = "Python LLM bot template"

[compatibility]
contract = { name = "pacto-contract", range = ">=0.1.0, <0.3.0" }
sdk = { name = "pacto-bot-sdk", range = ">=0.2.0, <0.3.0" }
daemon = { range = ">=0.4.1, <0.8.0" }

protected_files = ["bot.py", "tests/test_bot.py"]
```

### Top-level fields

| Field | Meaning |
|-------|---------|
| `manifest_version` | Schema version of this `manifest.toml`. Bumped when the manifest schema itself changes. |
| `language` | Target handler language. The CLI uses this with `kind` to pick a template. |
| `kind` | Bot kind within the language, e.g. `llm` or `governance`. |
| `description` | Short human-readable description shown in listings. |

### `[compatibility]` table

This table tells the resolver which released versions of the ecosystem the template can work with. The resolver must find a single contract/SDK/template triple that satisfies all three ranges.

| Key | What the version means | Example |
|-----|------------------------|---------|
| `contract` | Version of the published `pacto-contract-<version>.json` artifact. This artifact is the daemon’s JSON-RPC schema (`schemas/jsonrpc.json`) released as a standalone versioned file. It defines the methods, notifications, params, and result schemas that the daemon exposes and that the SDK uses. | `0.2.0` |
| `sdk` | PyPI version of `pacto-bot-sdk`. The SDK is generated from a specific contract artifact, so its version is tied to the contract it understands. | `0.2.1` |
| `daemon` | Version of the `pacto-bot-api` daemon binary. The daemon implements the contract, and the admin CLI is released from the same crate, so this range is checked against the CLI’s compile-time version. | `0.5.0` |

**Why the contract is separate:** the contract is the JSON-RPC boundary between the daemon and bot handlers. The daemon, the SDK, and the template must all agree on that boundary. Publishing the contract as its own versioned artifact lets the daemon and SDK release independently while still verifying compatibility.

### `protected_files`

A list of paths inside the rendered bot that the admin CLI should not overwrite during `pacto-bot-admin update` unless `--force` is passed. These are files the bot author is expected to edit by hand, such as the handler entry point and its tests.

### Note on `bot/manifest.json`

Inside the `bot/` directory you may also see a `manifest.json`. That is a different file used by the example contract-test harness: it declares which JSON-RPC contract pieces a bot exercises during CI. It is not the same as the template `manifest.toml` that the admin CLI reads.

## Usage

```bash
pacto-bot-admin new --scaffold echo-bot --backend nsec --relays ws://localhost:7000 --commands echo
```

The CLI clones this repository, selects the template by `--language` and `--kind`, resolves a compatible contract/SDK/template triple, and writes the rendered project along with a per-bot `scaffold.lock` file.

## Adding a template

1. Create a new directory named `<language>-<kind>`, e.g. `rust-llm`.
2. Add `cargo-generate.toml` with placeholders matching the values the admin CLI passes in.
3. Add `manifest.toml` with `manifest_version`, `[compatibility]` (contract, sdk, daemon), and `protected_files`.
4. Add `bot/` and `project/` subdirectories with the files to render.
5. Tag a new semver release so the resolver can discover it.

## License

MIT OR Apache-2.0
