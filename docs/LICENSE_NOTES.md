# License notes for bundled skills

The MIT license on **this repository** covers only the installer itself —
`scripts/*`, `registry.json`, `docs/*`, and the workflow files under
`.github/`. Every skill the installer puts on your disk keeps **its own**
license.

| Skill | Upstream | Upstream license | Bundled offline? |
| ----- | -------- | ---------------- | ---------------- |
| `document-skills` | [anthropics/skills](https://github.com/anthropics/skills) | Source-available (proprietary) | No |
| `frontend-design` | [anthropics/skills](https://github.com/anthropics/skills) | Source-available (proprietary) | No |
| `skill-creator`   | [anthropics/skills](https://github.com/anthropics/skills) | Source-available (proprietary) | No |
| `ui-ux-pro-max`   | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | MIT | Yes |
| `find-skills`     | [aqianer/find-skills](https://github.com/aqianer/find-skills) | MIT | Yes |
| `superpowers`     | [obra/superpowers-skills](https://github.com/obra/superpowers-skills) | MIT | Yes |

## The Anthropic three

Anthropic's `skills` repository ships under a **source-available** license,
which you can read at
[anthropics/skills/blob/main/LICENSE.txt](https://github.com/anthropics/skills/blob/main/skills/xlsx/LICENSE.txt).
It permits you (and only you) to use the code, but it does **not** grant
redistribution rights.

To stay on the right side of that license, `skills-installer` never
*re-hosts* those three skills:

- In default **online** mode, the installer performs a `git clone` from
  `anthropics/skills` into a temporary directory on **your** machine and
  copies the skill into **your** agent skills folder. Your machine, your
  use, your license grant from Anthropic.
- In `--offline` mode those three are **skipped** with a warning. If you
  need them offline, you must clone `anthropics/skills` yourself and
  manage the copy by hand — the installer will not create the redistribution
  on your behalf.

If Anthropic later releases these skills under a looser license, flip
`"redistributable": true` in `registry.json` and run
`scripts/sync-upstream.sh` to start bundling them too.

## Adding a skill with a different license

See [`ADDING_A_SKILL.md`](./ADDING_A_SKILL.md). The rule of thumb is:

- MIT / Apache-2.0 / BSD / ISC / CC0 / Unlicense → `"redistributable": true`;
  safe to mirror under `skills/`.
- GPL / AGPL / other strong-copyleft → `"redistributable": false` unless the
  **entire** skills-installer repo is willing to adopt the same license.
  Online mode still works fine.
- Source-available / proprietary → `"redistributable": false`. Online only.

When in doubt, stay safe: leave `"redistributable": false` and ship through
online mode.
