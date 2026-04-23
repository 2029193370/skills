# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| `v2.x`  | :white_check_mark: |
| `v1.x`  | Critical fixes only until 2027-01 |
| `< v1`  | :x:                |

We maintain the latest **major** and the previous major. Minor/patch upgrades are released regularly via [release-please](./.github/workflows/release-please.yml).

## Reporting a Vulnerability

**Do NOT open a public issue for security problems.**

Please use GitHub's private vulnerability reporting:

- Go to the [Security Advisories page](https://github.com/2029193370/ci-templates/security/advisories/new).
- Or email the maintainer via the GitHub profile.

### What to include

1. A concise description of the issue and the affected workflow / file path.
2. The version / commit SHA you observed the problem on.
3. Steps to reproduce (minimal example repo is ideal).
4. Impact assessment: what can an attacker achieve?
5. Your preferred contact and whether you wish to be credited.

### SLA

| Severity  | First response | Fix target |
|-----------|----------------|------------|
| Critical  | 24 hours       | 7 days     |
| High      | 72 hours       | 30 days    |
| Medium    | 7 days         | 90 days    |
| Low       | 14 days        | Best effort |

## Our Security Practices

This repository follows enterprise supply-chain best practices:

- **SHA-pinned Actions** - every third-party action is pinned by commit SHA (not by mutable tag). Dependabot keeps them current.
- **`step-security/harden-runner`** - every job enforces an egress firewall; the CI runtime can only reach an allow-listed set of hosts.
- **`actions: read`** default, per-job overrides only when strictly required.
- **Weekly CodeQL scan** with `security-extended` + `security-and-quality` query suites.
- **Weekly OpenSSF Scorecard scan** publishes results to the Security tab.
- **Gitleaks** scans the full git history on every push and PR.
- **zizmor** static analyser inspects every workflow for injection / permission / pinning issues.
- **Trivy** filesystem scan (vuln + secret) gated on `CRITICAL,HIGH`.
- **Signed releases** via SLSA build-provenance attestations (Level 3).

## Disclosure Policy

- Default: coordinated disclosure 90 days after initial report or when a fix is available, whichever comes first.
- We credit reporters in the release notes unless you ask us not to.
