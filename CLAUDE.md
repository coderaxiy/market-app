# market-app — Flutter customer app

Mobile client for the emarket customer website (`coderaxiy/emarket`, Astro storefront).
Same backend, same contract, same design language — different platform.

Read first: `.claude/skills/mobile-app/SKILL.md` (conventions), then the sibling repos:

- `coderaxiy/sdk-contract` — API contract. **Its `AGENTS.md` rules apply here.** Spec
  (`openapi/api.yaml`) beats docs, backend beats both. Don't guess the API; if a field or
  endpoint isn't in the spec, open a task in `sdk-contract/tasks/` (`to: backend`).
- `coderaxiy/emarket` — the storefront. Feature parity reference: `DESIGN.md`, `src/i18n/locales/`,
  `src/lib/api/`, `src/lib/format.ts`.

## Rules

1. Work in phases of **≤5 files**, verify, then stop for owner approval.
2. Done = `dart format --set-exit-if-changed .`, `flutter analyze` (zero issues) and
   `flutter test` all clean.
3. `sdk-contract` is the shared channel between backend, frontend and mobile: read it for the
   spec, docs and types, and read/write files in its `tasks/`. **Touch nothing else in it**;
   never edit `openapi/`, `sdk/`, `docs/` or scripts. Contract changes go through tasks.
4. Branch: develop on `claude/friendly-ptolemy-hlsoug`; no PRs unless asked.

## Session start

Pull `sdk-contract`, then `npm run tasks` there. Work the open tasks with `to: mobile`; leave
tasks addressed to other sides alone. See the "Tasks and contract updates" section of the skill.
