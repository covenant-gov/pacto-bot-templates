#!/usr/bin/env bash
# Print the current multi-arch index digest for library/python:3.14-slim.
# Does not modify files; paste the digest into python-llm/bot/Dockerfile after review.
set -euo pipefail

TAG="${1:-3.14-slim}"
REPO="library/python"

TOKEN="$(
  curl -fsSL \
    "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${REPO}:pull" \
    | python3 -c 'import sys, json; print(json.load(sys.stdin)["token"])'
)"

HEADERS="$(
  curl -fsSI \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json' \
    "https://registry-1.docker.io/v2/${REPO}/manifests/${TAG}" \
    | tr -d '\r'
)"

CONTENT_TYPE="$(printf '%s\n' "${HEADERS}" | awk -F': ' 'tolower($1)=="content-type"{print $2; exit}')"
DIGEST="$(printf '%s\n' "${HEADERS}" | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2; exit}')"

case "${CONTENT_TYPE}" in
  *image.index*|*manifest.list*)
    ;;
  *)
    echo "error: expected an OCI index / manifest list for ${TAG}; got: ${CONTENT_TYPE}" >&2
    exit 1
    ;;
esac

if [[ -z "${DIGEST}" ]]; then
  echo "error: missing docker-content-digest for ${TAG}" >&2
  exit 1
fi

echo "tag: python:${TAG}"
echo "content-type: ${CONTENT_TYPE}"
echo "index-digest: ${DIGEST}"
echo "platforms:"

curl -fsSL \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: ${CONTENT_TYPE}" \
  "https://registry-1.docker.io/v2/${REPO}/manifests/${TAG}" \
  | python3 -c "
import json, sys
index = json.load(sys.stdin)
for manifest in index.get('manifests', []):
    platform = manifest.get('platform') or {}
    if platform.get('os') == 'unknown':
        continue
    arch = platform.get('architecture', '?')
    variant = platform.get('variant')
    label = f'{arch}/{variant}' if variant else arch
    print(f'  - {label}: {manifest.get(\"digest\")}')
"
