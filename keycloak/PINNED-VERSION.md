# Keycloak Pinned Version

## Current Pin

| Field | Value |
|-------|-------|
| Image | `quay.io/keycloak/keycloak` |
| Tag | `26.2.5` |
| Digest | `sha256:4883630ef9db14031cde3e60700c9a9a8eaf1b5c24db1589d6a2d43de38ba2a9` |
| Distribution | Quarkus |
| Pinned on | 2026-06-20 |

> The digest above is the real multi-arch manifest digest for `quay.io/keycloak/keycloak:26.2.5`,
> captured via `docker inspect --format='{{index .RepoDigests 0}}' quay.io/keycloak/keycloak:26.2.5`.
> To verify locally: `docker pull quay.io/keycloak/keycloak:26.2.5 && docker inspect --format='{{index .RepoDigests 0}}' quay.io/keycloak/keycloak:26.2.5`

## Why We Pin

Keycloak upgrades require careful handling:
- **Database migrations**: Keycloak auto-migrates its schema; downgrade is not supported.
- **Theme API changes**: Custom themes may break across minor versions.
- **Admin REST API changes**: Endpoint paths and response shapes can shift between major versions.
- **SPI compatibility**: Third-party providers are version-specific.

Pinning to an exact tag (plus digest for supply-chain integrity) ensures:
1. Reproducible local dev environments for all team members.
2. CI builds produce the same artifact every time.
3. Deliberate, reviewed upgrades (not silent `latest` drift).

## How to Upgrade

1. Check https://quay.io/repository/keycloak/keycloak?tab=tags for the latest stable `26.x.y` tag.
2. Read the [Keycloak migration guide](https://www.keycloak.org/docs/latest/upgrading/) for that version.
3. Update the tag in `keycloak/Dockerfile` and `compose.yaml`.
4. Pull and record the new digest here.
5. Test locally: `docker compose up --build` and verify the realm imports cleanly.
6. Run the integration BATS tests: `tests/run-atdd.sh`.
7. Commit with a message referencing the upgrade rationale.

## Version History

| Date | Tag | Notes |
|------|-----|-------|
| 2026-06-20 | 26.2.5 | Initial scaffold (Story 1.1) |
