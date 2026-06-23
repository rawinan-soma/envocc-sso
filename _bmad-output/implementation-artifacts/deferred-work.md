# Deferred Work

Items intentionally deferred during review. Each entry notes its origin.

## Deferred from: code review of story-1.2 (2026-06-23)

- SMTP not configured (`smtpServer:{}`) while `resetPasswordAllowed:true` — forgot-password is functionally inert. SMTP config is not in story 1.2's ACs and configuring it in shared config-as-code would hardcode an environment-specific host. Wire SMTP (Mailpit in dev) in the auth/email story.
- `--import-realm` silently skips when the `envocc` realm already exists on a persistent Postgres volume, so edits to `realm-export.json` are ignored on subsequent `docker compose up` with no warning. Documented narratively in REALM-EXPORT-NOTES.md; add a CI/runbook guard (or an import-strategy override + drift check) later.
- Runtime BATS suite (`ac1-realm-config-runtime.bats`) silently SKIPs all live assertions when the admin token can't be obtained (e.g. unset `KEYCLOAK_ADMIN_PASSWORD` → `change-me` fallback). Live config could drift undetected. Make the suite fail loudly (vs skip) when the stack is up but auth is misconfigured.
- AC3 destructive re-import (`docker compose down -v && docker compose up`) is claimed complete (Task 4.2) but has no automated coverage and was not exercised this run (no Docker in the review environment). Add re-import smoke coverage once CI has Docker.
- `actionTokenGeneratedByAdminLifespan=43200` (12 h) is a Keycloak default that is loose relative to the realm's tight 15-min access-token posture. Confirm intentional or tighten in a later hardening pass; add a lint guard if tightened.
