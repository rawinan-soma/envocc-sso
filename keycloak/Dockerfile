# Keycloak Quarkus distribution — pinned to an immutable digest (not just the
# mutable tag) so the build is reproducible and supply-chain-verifiable. The tag
# is kept in the reference for human readability; the @sha256 is what's enforced.
# See keycloak/PINNED-VERSION.md for the digest record and upgrade instructions.
FROM quay.io/keycloak/keycloak:26.6.3@sha256:5fdbf2dbb5897cc34e82de49d13e23db011f9925089dbc555fc095f2c8bc1dac

# Copy the secrets-stripped baseline realm export into the import directory.
# Keycloak scans /opt/keycloak/data/import/ on startup when --import-realm is passed.
# Signing/encryption keys are auto-generated on first import (the KeyProvider
# components are omitted from the export, not committed with blank keys), and
# client secrets are blank ("") so Keycloak regenerates them.
# See keycloak/REALM-EXPORT-NOTES.md for the full list of stripped/omitted fields.
COPY realm-export.json /opt/keycloak/data/import/realm-export.json

# start-dev: HTTP only, no TLS, suitable for local development.
# --import-realm: import any realm JSON found in /opt/keycloak/data/import/ on startup.
# Do NOT use start-dev in production — use `start` with proper TLS and production DB config.
CMD ["start-dev", "--import-realm"]
