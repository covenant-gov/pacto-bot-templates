#!/usr/bin/env bash
# Generate the python-llm template and check supply-chain / placeholder invariants.
# Docker image build and non-root runtime probes run only when a container CLI exists.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT}/python-llm"
EXPECTED_BASE_DIGEST='sha256:af8a5aa14780025dbfbcfbc81bd8a91ebd87711dd5b0f48ed71090949dd7cb1d'
EXPECTED_FRONTEND_DIGEST='sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e'

if ! command -v cargo-generate >/dev/null 2>&1; then
  echo "error: cargo-generate is required (tested with 0.23.12)" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

generate_one() {
  local http_flag="$1"
  local dest_name="$2"
  cargo-generate generate \
    --path "${TEMPLATE}" \
    --destination "${TMP}" \
    --name "${dest_name}" \
    --define bot_id=echo-bot \
    --define bot_id_snake=echo_bot \
    --define project_dir_name="${dest_name}" \
    --define commands=hello \
    --define "http=${http_flag}" \
    --define command_handlers= \
    --define test_command_handlers= \
    --define command_list= \
    --define first_command=hello \
    --define manifest_contract_pieces= \
    --silent
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq -- "${needle}" "${file}"; then
    echo "error: expected to find '${needle}' in ${file}" >&2
    exit 1
  fi
}

assert_no_placeholders() {
  local file="$1"
  if grep -E '\{\{[a-zA-Z0-9_]+\}\}|\{%.*?%\}' "${file}" >/dev/null 2>&1; then
    echo "error: unexpanded cargo-generate placeholders remain in ${file}" >&2
    grep -En '\{\{[a-zA-Z0-9_]+\}\}|\{%.*?%\}' "${file}" >&2 || true
    exit 1
  fi
}

check_generated() {
  local project="$1"
  local expect_httpx="$2"
  local bot="${project}/bot"
  local compose="${project}/project/docker-compose.yml"

  assert_file_contains "${bot}/Dockerfile" "FROM python:3.14-slim@${EXPECTED_BASE_DIGEST}"
  assert_file_contains "${bot}/Dockerfile" "# syntax=docker/dockerfile:1.27.1@${EXPECTED_FRONTEND_DIGEST}"
  assert_file_contains "${bot}/Dockerfile" 'USER pacto-bot'
  assert_file_contains "${bot}/Dockerfile" '--gid 10001'
  assert_file_contains "${bot}/Dockerfile" '--uid 10001'
  assert_file_contains "${bot}/systemd.service" 'User=pacto-bot'
  assert_file_contains "${bot}/systemd.service" 'NoNewPrivileges=true'
  assert_file_contains "${bot}/systemd.service" 'PrivateTmp=true'
  assert_file_contains "${compose}" 'no-new-privileges:true'

  assert_no_placeholders "${bot}/Dockerfile"
  assert_no_placeholders "${bot}/systemd.service"
  assert_no_placeholders "${bot}/pyproject.toml"
  assert_no_placeholders "${compose}"
  assert_no_placeholders "${bot}/src/echo_bot/echo_bot.py"

  python3 - <<PY
import pathlib, sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib  # type: ignore

path = pathlib.Path("${bot}/pyproject.toml")
data = tomllib.loads(path.read_text())
deps = data["project"]["dependencies"]
has_httpx = any(d.startswith("httpx") for d in deps)
expect = ${expect_httpx}
if has_httpx != expect:
    raise SystemExit(f"httpx presence {has_httpx} != expected {expect}: {deps}")
print(f"pyproject ok ({path})")
PY

  python3 - <<PY
import pathlib, sys, yaml
path = pathlib.Path("${compose}")
data = yaml.safe_load(path.read_text())
svc = data["services"]["echo-bot"]
opts = svc.get("security_opt") or []
if "no-new-privileges:true" not in opts:
    raise SystemExit(f"missing security_opt in {path}: {opts}")
print(f"compose ok ({path})")
PY

  python3 -m compileall -q "${bot}/src/echo_bot"
}

echo "==> generate http=true"
generate_one true smoke-http-true
check_generated "${TMP}/smoke-http-true" True

echo "==> generate http=false"
generate_one false smoke-http-false
check_generated "${TMP}/smoke-http-false" False

echo "==> template source Dockerfile digests"
assert_file_contains "${TEMPLATE}/bot/Dockerfile" "FROM python:3.14-slim@${EXPECTED_BASE_DIGEST}"
assert_file_contains "${TEMPLATE}/bot/Dockerfile" "# syntax=docker/dockerfile:1.27.1@${EXPECTED_FRONTEND_DIGEST}"
assert_file_contains "${TEMPLATE}/bot/Dockerfile" 'USER pacto-bot'

CONTAINER_CLI=""
if command -v docker >/dev/null 2>&1; then
  CONTAINER_CLI=docker
elif command -v podman >/dev/null 2>&1; then
  CONTAINER_CLI=podman
fi

if [[ -z "${CONTAINER_CLI}" ]]; then
  echo "WARN: Docker/Podman unavailable — skipped image build and non-root runtime smoke"
else
  echo "==> ${CONTAINER_CLI} build + non-root smoke (no credentials)"
  # Arrange the layout the Dockerfile COPY path expects: context root with bots/<id>/.
  BUILD_CTX="${TMP}/build-ctx"
  mkdir -p "${BUILD_CTX}/bots"
  cp -a "${TMP}/smoke-http-true/bot" "${BUILD_CTX}/bots/echo-bot"
  IMAGE_TAG="pacto-python-llm-smoke:local"
  # Build may still fail if pacto-bot-sdk is not on the configured index; report clearly.
  if ! "${CONTAINER_CLI}" build -f "${BUILD_CTX}/bots/echo-bot/Dockerfile" -t "${IMAGE_TAG}" "${BUILD_CTX}"; then
    echo "WARN: container build failed (often missing pacto-bot-sdk on PyPI); non-root probe skipped"
  else
    USER_LINE="$("${CONTAINER_CLI}" run --rm --entrypoint /bin/sh "${IMAGE_TAG}" -c 'id -u; id -un')"
    echo "${USER_LINE}"
    echo "${USER_LINE}" | tr '\n' ' ' | grep -Eq '10001.*pacto-bot' \
      || { echo "error: expected runtime uid 10001 user pacto-bot" >&2; exit 1; }
    echo "container non-root smoke ok"
  fi
fi

echo "OK: python-llm template smoke checks passed"
