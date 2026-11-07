# Supply-chain notes (python-llm template)

This document covers the reproducible-image and privilege controls in the
`python-llm` cargo-generate template, and how maintainers refresh them.

## What is pinned today

| Artifact | Pin | Why |
|---|---|---|
| BuildKit Dockerfile frontend | `docker/dockerfile:1.27.1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e` | Tag `1` / `1.27.1` float; digest freezes the frontend. |
| Bot base image | `python:3.14-slim@sha256:af8a5aa14780025dbfbcfbc81bd8a91ebd87711dd5b0f48ed71090949dd7cb1d` | Multi-arch **index** digest for tag `3.14-slim` (verified as `3.14.10-slim-trixie`). Using the index (not an amd64-only manifest) preserves arm64 and other published architectures. |
| Runtime user | `pacto-bot` uid/gid `10001` in the image; `User=` / `Group=` in `systemd.service` | Avoid root at runtime. Compose relies on the image `USER`. |

## What is intentionally not locked yet

`pyproject.toml` keeps minimum-version ranges (`pacto-bot-sdk>=0.2.0`, optional
`httpx>=0.27`) so the admin CLI compatibility resolver and local editable
installs keep working.

A hashed `requirements.txt` for `pip install --require-hashes` is **not**
shipped while `https://pypi.org/pypi/pacto-bot-sdk/json` returns 404. Inventing
or single-platform-freezing hashes would break installs or falsely claim
reproducibility. When the SDK is publish-verifiable on PyPI, follow
[Hashed runtime lock](#hashed-runtime-lock-when-sdk-is-on-pypi) below.

## Refresh the Python base image digest

Re-verify against Docker Hub’s registry API (do not copy digests from blog
posts or untrusted mirrors):

```bash
TOKEN=$(curl -fsSL \
  'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/python:pull' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

curl -fsSI \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json' \
  'https://registry-1.docker.io/v2/library/python/manifests/3.14-slim' \
  | tr -d '\r' | grep -i docker-content-digest
```

Confirm the response `Content-Type` is an **index** / manifest **list**, then
list platforms before updating `python-llm/bot/Dockerfile`:

```bash
curl -fsSL \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Accept: application/vnd.oci.image.index.v1+json' \
  'https://registry-1.docker.io/v2/library/python/manifests/3.14-slim' \
  | python3 -c '
import json, sys
index = json.load(sys.stdin)
parts = []
for manifest in index["manifests"]:
    platform = manifest.get("platform") or {}
    if platform.get("os") == "unknown":
        continue
    arch = platform.get("architecture", "?")
    variant = platform.get("variant")
    parts.append(f"{arch}/{variant}" if variant else arch)
print(", ".join(parts))
'
```

Update the `FROM` line and the comment date in the Dockerfile together.

Helper script (same checks): `scripts/refresh-python-base-digest.sh`.

## Refresh the Dockerfile frontend digest

```bash
TOKEN=$(curl -fsSL \
  'https://auth.docker.io/token?service=registry.docker.io&scope=repository:docker/dockerfile:pull' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

curl -fsSI \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json' \
  'https://registry-1.docker.io/v2/docker/dockerfile/manifests/1.27.1' \
  | tr -d '\r' | grep -i docker-content-digest
```

Prefer a specific `1.x.y` tag plus its index digest in the `# syntax=` line.

## Hashed runtime lock (when SDK is on PyPI)

Prerequisites:

1. `curl -fsSIL https://pypi.org/pypi/pacto-bot-sdk/json` returns HTTP 200.
2. Record the chosen SDK version’s artifact SHA256 digests from that JSON
   (`urls[].digests.sha256`) for every published file you will accept
   (wheel and/or sdist).
3. Generate hashes on a maintainer machine with network access to PyPI, for
   **both** `http=true` and `http=false` scaffolds if you keep the conditional
   dependency, or collapse to one lock if the project always includes HTTP.

Example flow (illustrative; adjust versions to what you verified):

```bash
python -m pip install 'pip-tools>=7'
# After rendering a bot (or using a throwaway pyproject), compile with hashes:
pip-compile --generate-hashes -o requirements.txt requirements.in
# Confirm every line’s sha256 matches PyPI JSON for that version/filename.
```

Then change the bot Dockerfile install stage to something equivalent to:

```dockerfile
COPY bots/{{bot_id}}/requirements.txt ./
RUN pip install --no-cache-dir --disable-pip-version-check --require-hashes -r requirements.txt
COPY bots/{{bot_id}}/ ./
RUN pip install --no-cache-dir --disable-pip-version-check --no-deps .
```

Do not commit a lock file until the SDK hashes were fetched from PyPI (or another
explicit, documented index) in the same change.

## Non-root runtime notes

- **Container:** image `USER pacto-bot` (uid/gid 10001). Compose adds
  `no-new-privileges`. The daemon Unix socket must be accessible to that
  uid/gid, or set `PACTO_TRANSPORT=http` with a shared secret.
- **systemd:** already ran as `pacto-bot`; this template also sets
  `NoNewPrivileges=true` and `PrivateTmp=true`.
- **Local editable installs** (`pip install -e` / `make install`) are unchanged
  and still run as the developer’s user.

## Smoke checks

From the repository root:

```bash
./scripts/smoke-python-llm-template.sh
```

That script generates the template with `cargo-generate`, checks digest/`USER`
placeholders expanded, validates compose YAML and `pyproject.toml`, and reports
when Docker is unavailable for an image build / non-root runtime probe.
