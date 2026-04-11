FROM node:lts-trixie-slim AS base

ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gosu \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    wget \
 && rm -rf /var/lib/apt/lists/* \
 && corepack enable

RUN usermod -u $USER_UID --non-unique node \
 && groupmod -g $USER_GID --non-unique node \
 && usermod -g $USER_GID -d /paperclip node

FROM base AS deps

WORKDIR /app

COPY upstream-paperclip/package.json upstream-paperclip/pnpm-workspace.yaml upstream-paperclip/pnpm-lock.yaml upstream-paperclip/.npmrc ./
COPY upstream-paperclip/cli/package.json cli/
COPY upstream-paperclip/server/package.json server/
COPY upstream-paperclip/ui/package.json ui/
COPY upstream-paperclip/packages/shared/package.json packages/shared/
COPY upstream-paperclip/packages/db/package.json packages/db/
COPY upstream-paperclip/packages/adapter-utils/package.json packages/adapter-utils/
COPY upstream-paperclip/packages/adapters/claude-local/package.json packages/adapters/claude-local/
COPY upstream-paperclip/packages/adapters/codex-local/package.json packages/adapters/codex-local/
COPY upstream-paperclip/packages/adapters/cursor-local/package.json packages/adapters/cursor-local/
COPY upstream-paperclip/packages/adapters/gemini-local/package.json packages/adapters/gemini-local/
COPY upstream-paperclip/packages/adapters/openclaw-gateway/package.json packages/adapters/openclaw-gateway/
COPY upstream-paperclip/packages/adapters/opencode-local/package.json packages/adapters/opencode-local/
COPY upstream-paperclip/packages/adapters/pi-local/package.json packages/adapters/pi-local/
COPY upstream-paperclip/packages/plugins/sdk/package.json packages/plugins/sdk/
COPY upstream-paperclip/patches/ patches/

RUN pnpm install --frozen-lockfile

FROM base AS build

WORKDIR /app

COPY --from=deps /app /app
COPY upstream-paperclip/ /app/

RUN pnpm --filter @paperclipai/ui build
RUN pnpm --filter @paperclipai/plugin-sdk build
RUN pnpm --filter @paperclipai/server build
RUN test -f server/dist/index.js || (echo "ERROR: server build output missing" && exit 1)

FROM base AS production

WORKDIR /app

COPY --chown=node:node --from=build /app /app
COPY upstream-hermes/ /tmp/upstream-hermes/

RUN npm install --global --omit=dev @anthropic-ai/claude-code@latest @openai/codex@latest opencode-ai \
 && python3 -m pip install --no-cache-dir --break-system-packages "/tmp/upstream-hermes[cli,pty,mcp,honcho]" \
 && rm -rf /tmp/upstream-hermes \
 && mkdir -p /paperclip /paperclip/hermes-home \
 && chown node:node /paperclip /paperclip/hermes-home

ENV NODE_ENV=production \
    HOME=/paperclip \
    HOST=0.0.0.0 \
    PORT=3100 \
    SERVE_UI=true \
    PAPERCLIP_HOME=/paperclip \
    PAPERCLIP_INSTANCE_ID=default \
    USER_UID=${USER_UID} \
    USER_GID=${USER_GID} \
    PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
    PAPERCLIP_DEPLOYMENT_MODE=authenticated \
    PAPERCLIP_DEPLOYMENT_EXPOSURE=private \
    HERMES_HOME=/paperclip/hermes-home \
    OPENCODE_ALLOW_ALL_MODELS=true

VOLUME ["/paperclip"]

EXPOSE 3100

USER node

CMD ["node", "--import", "./server/node_modules/tsx/dist/loader.mjs", "server/dist/index.js"]
