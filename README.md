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
