# Deferred Work

Items surfaced during reviews that are real but intentionally not actioned in the originating story. Pull these forward into the noted future story or an infra-hardening pass.

## Deferred from: code review of story-1.1 (2026-06-25)

- **Healthcheck `cat <&3` has no client-side read timeout** [compose.yaml] — The Keycloak readiness probe reads the management socket until EOF, relying on the server honoring `Connection: close`. Already bounded by Docker `healthcheck.timeout: 10s` and confirmed by live boot, so low risk. Consider wrapping the read in `timeout`/`read -t` during infra hardening.
- **Maintenance DBs (`postgres`, `template1`) remain PUBLIC-connectable by both roles** [postgres/init/01-init-databases.sh] — AC2's pairwise isolation (keycloak ↔ admin) is fully enforced. For stricter least-privilege, add `REVOKE CONNECT ON DATABASE postgres, template1 FROM PUBLIC` (and re-grant the superuser as needed). Defer to Story 1.5 / infra hardening.
- **`pg_isready` healthcheck does not assert the `keycloak` DB exists** [compose.yaml] — Postgres can report healthy before init scripts finish in theory; mitigated in practice because the official entrypoint does not open the TCP listener until init completes. A stricter gate (`pg_isready -d keycloak` or a `SELECT`) would make the AC1 ordering guarantee explicit.
- **Integration tests share the developer's named volume / no isolated compose project** [tests/] — `compose_down_volumes` in the test helpers operates on the same `postgres_data` volume as a developer's running stack. Give the test stack its own compose project name / volume namespace when the CI gate lands (Story 1.5).
