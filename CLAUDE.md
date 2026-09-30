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
3. Never edit `sdk-contract/openapi/` or `sdk-contract/sdk/`. Contract changes go through tasks.
4. Branch: develop on `claude/friendly-ptolemy-hlsoug`; no PRs unless asked.
