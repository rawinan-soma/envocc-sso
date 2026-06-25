# Deferred Work

Items surfaced during reviews that are real but intentionally not actioned in the originating story. Pull these forward into the noted future story or an infra-hardening pass.

## Deferred from: code review of story-1.1 (2026-06-25)

- **Healthcheck `cat <&3` has no client-side read timeout** [compose.yaml] — The Keycloak readiness probe reads the management socket until EOF, relying on the server honoring `Connection: close`. Already bounded by Docker `healthcheck.timeout: 10s` and confirmed by live boot, so low risk. Consider wrapping the read in `timeout`/`read -t` during infra hardening.
- **Maintenance DBs (`postgres`, `template1`) remain PUBLIC-connectable by both roles** [postgres/init/01-init-databases.sh] — AC2's pairwise isolation (keycloak ↔ admin) is fully enforced. For stricter least-privilege, add `REVOKE CONNECT ON DATABASE postgres, template1 FROM PUBLIC` (and re-grant the superuser as needed). Defer to Story 1.5 / infra hardening.
- **`pg_isready` healthcheck does not assert the `keycloak` DB exists** [compose.yaml] — Postgres can report healthy before init scripts finish in theory; mitigated in practice because the official entrypoint does not open the TCP listener until init completes. A stricter gate (`pg_isready -d keycloak` or a `SELECT`) would make the AC1 ordering guarantee explicit.
- **Integration tests share the developer's named volume / no isolated compose project** [tests/] — `compose_down_volumes` in the test helpers operates on the same `postgres_data` volume as a developer's running stack. Give the test stack its own compose project name / volume namespace when the CI gate lands (Story 1.5).

## Deferred from: code review of story-1.3 (2026-06-25)

- **No `resolver` for `proxy_pass http://keycloak:8080`** [nginx/nginx.conf] — nginx resolves the `keycloak` upstream name once at worker start and caches the IP. A Keycloak-only restart that changes its container IP leaves nginx proxying a stale IP (502 Bad Gateway) until nginx is reloaded/restarted; `depends_on: service_healthy` only orders the initial start. Live boot is verified, so low risk for the current sequential workflow. Fix during infra hardening with `resolver 127.0.0.11 valid=30s;` + a variable upstream (note: variable `proxy_pass` changes URI handling, so test carefully).
- **Host-header reflection in port-80 redirect** [nginx/nginx.conf] — `return 301 https://$host$request_uri;` with `server_name _` reflects an arbitrary client Host header into the redirect Location, and the same `$host` is forwarded to Keycloak with `KC_HOSTNAME_STRICT=false`. Benign for local dev; production hardening should add a `server_name` allowlist / fixed redirect host. Explicitly out of scope for this local-dev story (production TLS/hostname handling is deferred to the production-deployment work).
