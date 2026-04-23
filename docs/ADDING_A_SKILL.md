# Adding a skill to skills-installer

The installer is driven entirely by [`registry.json`](../registry.json) — no
code change is required to ship a new skill. This doc walks through adding
one end-to-end.

## 1. Prerequisites for the upstream repository

Your skill lives in a public GitHub repository and the skill itself is a
directory that contains a `SKILL.md` file at its root, matching the standard
format used across Cursor, Claude Code, Codex and Windsurf:

```
your-skill/
  SKILL.md              # required: YAML frontmatter + Markdown body
  references/           # optional supporting files
  scripts/              # optional helper scripts
```

If your repo hosts multiple skills (like `anthropics/skills` or
`obra/superpowers-skills`), each skill must still sit in its own directory
that can be sparse-checked out on its own.

## 2. Add an entry to `registry.json`

Copy one of the existing entries. The fields are documented by
[`registry.schema.json`](../registry.schema.json):

```json
{
  "name": "your-skill",
  "title": "Your Skill",
  "description": "One sentence that explains when this skill fires.",
  "upstream": "https://github.com/your-org/your-skill-repo",
  "branch": "main",
  "license": "MIT",
  "redistributable": true,
  "paths": ["skills/your-skill"],
  "tags": ["domain", "whatever"]
}
```

Field notes:

- **`name`** — lowercase kebab-case. Becomes the top-level directory under the
  target agent's skills folder, and the selector for `--skills=<name>`.
- **`paths`** — subpaths inside the upstream repo. Use `["."]` if the repo
  *is* the skill. Use multiple entries if you want several sibling skill
  directories to be installed together.
- **`installAs`** — optional parent folder name when you install multiple
  paths as a group (e.g. `document-skills` groups `xlsx`, `docx`, `pdf`,
  `pptx`).
- **`flatten`** — `true` when the `paths[0]` points at a directory whose
  *children* are each a full skill. Used by `superpowers` because its
  upstream groups skills into `architecture/`, `collaboration/`, etc.
- **`redistributable`** — set to `false` for source-available / proprietary
  licenses. Installer fetches from upstream in online mode; `--offline`
  skips the skill with a warning.

## 3. Validate locally

The CI runs [`ci-lint.yml`](../.github/workflows/ci-lint.yml) to validate
`registry.json` against the schema. Run it yourself before opening a PR:

```bash
pip install jsonschema
python -c "
import json, jsonschema
schema = json.load(open('registry.schema.json'))
data   = json.load(open('registry.json'))
jsonschema.validate(data, schema)
print('OK')
"
```

Then dry-run the installer end to end:

```bash
bash scripts/install.sh --dry-run --agent=cursor --skills=your-skill
```

## 4. (Optional) mirror the skill for `--offline`

If the license allows redistribution (MIT / Apache / BSD / ISC / …), run the
maintainer sync script so your skill shows up under `skills/`:

```bash
bash scripts/sync-upstream.sh your-skill
git add skills/your-skill
git commit -m "chore: mirror your-skill for offline install"
```

Source-available licenses — Anthropic's `document-skills`,
`frontend-design`, `skill-creator` are the reference examples — should
**not** be mirrored. The installer handles them by setting
`redistributable: false` and skipping them in `--offline` mode.

## 5. Open the PR

Use a Conventional Commit title, for example:

```
feat(registry): add your-skill skill
```

The release-please bot will later roll this up into the next minor version
and bump the sliding major tag accordingly. See the
[release workflow](../.github/workflows/release-please.yml) for details.
