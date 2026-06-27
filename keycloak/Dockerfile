# keycloak/Dockerfile
# Pinned Keycloak 26.6.3 build for the envocc-sso foundation stack.
#
# Digest pinned at image resolution time — verify before updating:
#   docker buildx imagetools inspect quay.io/keycloak/keycloak:26.6.3
FROM quay.io/keycloak/keycloak:26.6.3@sha256:9b0330756022422149aa6502eb2def8cd47c6e1b000c7c65cdb13e7c0133e992

# Story 2.5: Bake the Deep Sea login theme into the image.
# Build context = ./keycloak/ — all COPY sources are relative to keycloak/.
# Themes must be present BEFORE the optimised build step (Quarkus compiles them in).
# design-tokens/deep-sea.css is inside the theme directory
# (keycloak/themes/envocc/login/resources/design-tokens/) and is included
# automatically by the COPY below — NO separate COPY for tokens is needed.
COPY themes/envocc /opt/keycloak/themes/envocc

# Build the optimised Keycloak distribution:
#   --db=postgres          pre-compiles Postgres JDBC wiring
#   --health-enabled=true  enables /health/ready on management port 9000
#
# KC_HEALTH_ENABLED is a BUILD-TIME option in KC 26 (Quarkus).
# It MUST be passed to `kc.sh build`, NOT set as a compose.yaml env var.
# Setting it only in compose.yaml environment causes crash-loop on
# `start --optimized` because the feature was not compiled in.
#
# Story 1.2: realm import support is now baked in via COPY + --import-realm.
# Event-listener providers belong to Story 5.1.
RUN /opt/keycloak/bin/kc.sh build --db=postgres --health-enabled=true

# Bake the baseline realm config into the image.
# KC 26 auto-imports all *.json files placed in /opt/keycloak/data/import/
# when started with --import-realm. Import strategy: IGNORE_EXISTING (default)
# — realm is only imported on a fresh (empty) database. On an existing DB,
# the import file is silently skipped. Use `docker compose down -v` to reset.
# (Story 1.2 scope — full OIDC clients, roles, and MFA added in Epic 2.)
COPY realm-export.json /opt/keycloak/data/import/realm-export.json

# Use the optimised distribution for fast, deterministic production boots.
# --import-realm triggers auto-import from /opt/keycloak/data/import/ on startup.
# `start-dev` is for throwaway local development only and is not appropriate here.
CMD ["start", "--optimized", "--import-realm"]
