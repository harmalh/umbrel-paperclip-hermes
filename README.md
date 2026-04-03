# umbrel-paperclip-hermes

Umbrel packaging for **Paperclip Hermes**, a Hermes-enabled Paperclip variant.

This repo keeps the working Umbrel bootstrap pattern from `umbrel-paperclip`
while building a custom Paperclip image that includes the Hermes CLI runtime.

## Canonical install surface

Add this store in umbrelOS:

`https://github.com/harmalh/umbrel-community-store`

Install **Paperclip Hermes** (`harmalh-paperclip-hermes`).

## Source Pins

- Paperclip upstream:
  `paperclipai/paperclip@v2026.325.0`
- Hermes Agent upstream:
  `NousResearch/hermes-agent@v2026.3.30`

Current upstream Paperclip already vendors `hermes-paperclip-adapter` and
registers `hermes_local` in its server adapter registry, so this package does
not carry a separate registry patch for the pinned upstream version.

## Umbrel Topology

```text
Umbrel browser
  -> app_proxy
  -> bootstrap sidecar
  -> Paperclip web server
  -> Hermes runtime inside the same image
```

Runtime state lives entirely under `${APP_DATA_DIR}/data`.

## Build And Publish

Use `.github/workflows/build-paperclip-hermes-image.yml` to build and optionally
push:

- `ghcr.io/harmalh/paperclip-hermes-umbrel`

After the first push, replace the tag-only image reference in
`app/docker-compose.yml` with a digest-pinned image reference before release.

## Release To Community Store

Copy `app/` into:

`umbrel-community-store/harmalh-paperclip-hermes/`

This repo already uses the prefixed app id, so the synced compose and hooks can
stay identical in the community store copy.

## Validation Scope

CI validates YAML and workflows. The build workflow also smoke-tests:

- Paperclip `/api/health`
- `hermes --help` inside the running container
- `hermes_local` registration in the built Paperclip server
