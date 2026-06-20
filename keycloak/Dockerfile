# Keycloak Quarkus distribution — pinned to exact patch version
# See keycloak/PINNED-VERSION.md for upgrade instructions and digest record.
FROM quay.io/keycloak/keycloak:26.2.5

# Copy the secrets-stripped baseline realm export into the import directory.
# Keycloak scans /opt/keycloak/data/import/ on startup when --import-realm is passed.
# Secrets (privateKey, certificate, clientSecret, hmac secret) are auto-generated on first import.
# See keycloak/REALM-EXPORT-NOTES.md for the full list of stripped fields.
COPY realm-export.json /opt/keycloak/data/import/realm-export.json

# start-dev: HTTP only, no TLS, suitable for local development.
# --import-realm: import any realm JSON found in /opt/keycloak/data/import/ on startup.
# Do NOT use start-dev in production — use `start` with proper TLS and production DB config.
CMD ["start-dev", "--import-realm"]
