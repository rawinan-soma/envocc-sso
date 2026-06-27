# Deferred Work

Items surfaced during reviews that are real but intentionally not actioned in the originating story. Pull these forward into the noted future story or an infra-hardening pass.

## Deferred from: code review of story-1.1 (2026-06-25)

- **Healthcheck `cat <&3` has no client-side read timeout** [compose.yaml] — The Keycloak readiness probe reads the management socket until EOF, relying on the server honoring `Connection: close`. Already bounded by Docker `healthcheck.timeout: 10s` and confirmed by live boot, so low risk. Consider wrapping the read in `timeout`/`read -t` during infra hardening.
- **Maintenance DBs (`postgres`, `template1`) remain PUBLIC-connectable by both roles** [postgres/init/01-init-databases.sh] — AC2's pairwise isolation (keycloak ↔ admin) is fully enforced. For stricter least-privilege, add `REVOKE CONNECT ON DATABASE postgres, template1 FROM PUBLIC` (and re-grant the superuser as needed). Defer to Story 1.5 / infra hardening.
- **`pg_isready` healthcheck does not assert the `keycloak` DB exists** [compose.yaml] — Postgres can report healthy before init scripts finish in theory; mitigated in practice because the official entrypoint does not open the TCP listener until init completes. A stricter gate (`pg_isready -d keycloak` or a `SELECT`) would make the AC1 ordering guarantee explicit.
- **Integration tests share the developer's named volume / no isolated compose project** [tests/] — `compose_down_volumes` in the test helpers operates on the same `postgres_data` volume as a developer's running stack. Give the test stack its own compose project name / volume namespace when the CI gate lands (Story 1.5).

## Deferred from: code review of story-1.5 (2026-06-26)

- **`eval(expression)` in `compose_service_field` test helper** [tests/helpers/common.bash:140] — The helper evaluates a caller-supplied Python expression string. Test-only, and every current call site passes a hardcoded literal (no untrusted input), so the risk is contained. Replace with an explicit accessor (dotted-path getter) during a test-infra cleanup pass.
- **Realm-lint required-field check is presence-only** [scripts/lint-realm-export.py] — `realm`/`enabled`/`bruteForceProtected`/`accessTokenLifespan` are asserted present but not validated for sane values; an empty or `null` value (e.g. `"bruteForceProtected": null`) passes lint. The story spec only required presence assertion. Add value validation if the realm baseline is ever tightened.

## Deferred from: code review of story-1.2 (2026-06-25)

- **CI workflow branch triggers do not match the project branch model** [.github/workflows/ci.yml] — Triggers are `push: [main, develop, story-*]` / `pull_request: [main, develop]`, but the actual Git Flow is `main`/`dev`/`epic-N` (no `develop`, no `story-*` push branches; integration happens on `epic-N`). A PR from `epic-1` → `dev` would not match, so the `gitleaks` and `realm-export-check` gates (the AC2 enforcement) may never run on the real merge path. Pre-existing from Story 1.1, out of scope for this diff. Reconcile branch names (`develop`→`dev`, add `epic-*`) when the CI security gate is finalized in Story 1.5.

## Deferred from: code review of story-2.1 (2026-06-27)

- **`test-ropc-client` (ROPC/direct-access grant) ships in the shared realm export with no enforced production removal** [keycloak/realm-export.json] — The client is documented as test-only (warnings in `REALM-EXPORT-NOTES.md` and `IDENTITY-MODEL.md`, secret zeroed), but nothing mechanically prevents it from being imported into a non-dev environment, where a confidential ROPC client is a credential-stuffing surface. Out of scope for Story 2.1 (identity model); address during the production-hardening / deployment pass — e.g. a separate prod realm export, or a lint rule that rejects `directAccessGrantsEnabled` clients in production exports.
