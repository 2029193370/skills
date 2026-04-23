# Contributing

Thanks for your interest in improving this template!

## Ground rules

- PR titles follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(ci): add foo`, `fix(docker): bar`, `docs(readme): baz`, etc.
- Every third-party GitHub Action must be pinned by commit SHA.
  The tag is kept as a comment: `uses: owner/action@<sha> # <tag>`.
- Every workflow job declares:
  - an explicit `permissions:` block,
  - a `timeout-minutes:` value,
  - `step-security/harden-runner` as the first step.
- Every new workflow must pass `yamllint -c .yamllint` and `zizmor`.

## Local validation

```bash
pip install yamllint
yamllint -c .yamllint .github/workflows starter/.github/workflows .github/dependabot.yml
```

(Optional) install `zizmor`:

```bash
pipx install zizmor
zizmor .github/workflows
```

## Updating a pinned action

1. Wait for Dependabot to open the PR, or open one manually.
2. Keep the `# vX.Y.Z` trailing comment in sync with the new tag.
3. Verify the SHA resolves to a commit on the **public** action repo
   (`gh api repos/<owner>/<repo>/commits/<tag> --jq .sha`).

## Release process

Releases are automated by [release-please](./.github/workflows/release-please.yml).
Merging a commit with a Conventional prefix triggers it to open / update a
release PR that bumps the version and regenerates `CHANGELOG.md`.

The sliding `v1` / `v2` major tags are updated automatically by the same
workflow after a release is published, so consumer repos pinned at `@v1`
receive new minor/patch releases without any action on their part.

## Branching

- Feature branches: `feat/short-name`
- Bugfix branches:  `fix/short-name`
- Never push directly to `main`; PR + at least one approval is required
  (configured via branch protection).
