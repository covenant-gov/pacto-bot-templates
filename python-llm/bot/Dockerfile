# syntax=docker/dockerfile:1.27.1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
# python:3.14-slim — pin the multi-arch OCI *index* digest (not a single-arch
# manifest) so amd64/arm64/etc. keep resolving. Verified 2026-11-07 against
# registry-1.docker.io (tag 3.14-slim → python 3.14.10-slim-trixie).
# Refresh procedure: docs/supply-chain.md
FROM python:3.14-slim@sha256:af8a5aa14780025dbfbcfbc81bd8a91ebd87711dd5b0f48ed71090949dd7cb1d

# Fixed uid/gid so Compose/host bind mounts stay predictable across rebuilds.
# Matches the non-root identity documented in systemd.service (name only;
# host installs may use a different numeric id from useradd).
RUN groupadd --system --gid 10001 pacto-bot \
    && useradd --system --uid 10001 --gid pacto-bot \
       --home-dir /app --shell /sbin/nologin pacto-bot

WORKDIR /app/bots/{{bot_id}}

# Copy the bot package and install it. The bot depends on the pacto-bot-sdk
# package from PyPI, which is resolved automatically by pip.
# Hashed runtime locks are deferred until pacto-bot-sdk is publish-verifiable
# on PyPI (see docs/supply-chain.md); do not invent hashes.
COPY bots/{{bot_id}}/ ./
RUN pip install --no-cache-dir --disable-pip-version-check . \
    && chown -R pacto-bot:pacto-bot /app

USER pacto-bot

ENTRYPOINT ["python", "-m", "{{bot_id_snake}}"]
CMD []
