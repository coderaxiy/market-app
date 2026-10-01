---
name: mobile-app
description: Conventions and gotchas for the market-app Flutter customer app (mirrors the emarket storefront). Read before changing anything in this repo.
---

# market-app — conventions

The app is the mobile twin of the emarket storefront. Where this file is silent, do what the
storefront does (`coderaxiy/emarket`, its `.claude/skills/storefront/SKILL.md` and `DESIGN.md`).

## Process
- Phases of **≤5 files**, verify, stop for owner approval.
- Verify with `dart format`, `flutter analyze`, `flutter test`.

## API
- Contract lives in `sdk-contract`. Follow `docs/api-standards.md` (auth, error shape,
  pagination, money, dates) and the module docs, notably `storefront-catalog-api.md`,
  `orders-and-payments-api.md`, `logistics-and-pickup-points-api.md`.
- There is **no generated Dart SDK**. Like the storefront, use hand-written models that mirror
  `openapi/api.yaml`: one file per entity, each naming the schema it mirrors; one HTTP client
  (dio) with every path in a single `endpoints.dart`. When the spec changes, update the
  matching model by hand from the spec diff.
- Base URL is the host only (paths already include `/api/v1`). Dev backend: `http://localhost:8000`
  (Android emulator: `http://10.0.2.2:8000`).
- **Auth is an httpOnly `access_token` cookie** from `POST /api/v1/auth/login`. Use a persistent
  cookie jar (`dio_cookie_manager` + `cookie_jar` with `PersistCookieJar`); without it every
  call after login is 401. Store the jar in app-private storage.
- Errors: one helper (like the storefront's `apiErrorMessage`, `isForbidden`) turns the
  standard error shape into a localized message. Never show raw server text blindly.

## Tasks and contract updates
`sdk-contract` is the exchange point with backend/frontend. Only read it (spec, docs, types)
and read/write files in `tasks/`. Never edit anything else there. Our side is `mobile`.

- **Session start:** `git pull` in `sdk-contract`, `npm run tasks`, pick up open tasks with
  `to: mobile`. Don't touch tasks for other sides except to reply in a new task.
- **"There are new updates in the SDK contract":**
  1. Check: `git log --oneline ORIG_HEAD..HEAD`, `git diff --stat ORIG_HEAD..HEAD`. Read open
     `to: mobile` tasks, then changed `docs/`, then the `openapi/api.yaml` diff (the exact list
     of added/removed/changed endpoints, fields, enums, including ones no task mentions).
  2. Verify: task and spec must agree; the spec is what's running. Find every use of the
     changed endpoints/schemas in the app. If unclear or contradictory, don't guess: create a
     reply task (`reply_to: <id>`, `to: backend`) and move on.
  3. Implement: update the hand-written models/endpoints from the spec diff, then run
     format/analyze/tests.
  4. Close: in the task set `status: closed`, `closed: <today>`, add a `## Resolution`
     (screens, files, commit). Then `npm run tasks:check`, commit and push `sdk-contract`.
- **New request:** `npm run task:new -- <kebab-id> <backend|frontend>`; be concrete (endpoint,
  fields, types, current vs expected, why). Status is only `open` or `closed`. Never delete tasks.
- Don't invent endpoints or fields: if it isn't in the spec or docs, open a task.

## Session and push (from sdk-contract docs)
- The `access_token` cookie lasts 7 days from login, fixed (not sliding), no refresh. A 401
  on an ordinary call drops the user (`createApiClient(onUnauthorized:)` -> `expire()`); the
  persistent cookie jar keeps it across restarts. Need longer? Open a task to backend.
- Password reset is a 6-digit emailed code (no deep link): `requestPasswordReset`, then
  `confirmPasswordReset`; it does not log in. `new_password` is 8-72 bytes.
- Push: `PUT /devices` after login and on locale/token change, `DELETE /devices?token=` before
  logout (both done by `DeviceService`). Real tokens need Firebase (`PushTokenSource`; until
  then `NoPushTokenSource`). Backend delivery is console-only for now (docs/notifications-api.md).

## Money & numbers
- Whole soʻm only. Hand-written `formatMoney` / `formatNumber` that print the same as the
  storefront: `15 000 soʻm` (uz) / `15 000 сум` (ru) / `15,000 UZS` (en). Do not use
  `NumberFormat` with the `uz` locale: data is inconsistent across platforms.

## i18n
- Locales: `uz` (primary), `ru`, `en`. Mirror the key shape of emarket's `src/i18n/locales/en.ts`
  so translations can be shared/ported. Same `pickTranslation` fallback behavior for
  server-provided multilingual fields.
- Locale change is app-wide and persisted.

## Design
- Mirror emarket `DESIGN.md`: "Modern Silk Road bazaar", warm, product-first.
- Colour **tokens only** in a `ThemeExtension` (background, foreground, muted, card, primary,
  accent, secondary, destructive, success, warning, sale, border, ring). No raw hex in widgets.
  Take values from emarket's `src/styles/global.css` (light and dark).
- `primary` (saffron-pomegranate) is for commerce actions only; `accent` (turquoise) for
  links/selection/focus. Dark mode: raised surfaces are *lighter* (background < muted < card).
- Theme: `light | dark | system`, persisted. Radius base 16.
- Fonts: Unbounded (display, titles only) and Onest (body/UI); bundle them, Latin + Cyrillic.
- Girih pattern only for dividers/empty states/auth backdrop, never behind product images.

## Structure (feature-first)
- `lib/core/` — api client, endpoints, errors, auth/cookie jar, i18n, format, theme.
- `lib/features/<feature>/` — `data/` (models, repository), `presentation/`.
- State management and routing: decide once with the owner in phase 1, then stay consistent.

## Maps
- Pickup-point picker uses Yandex Maps in the storefront (keys in git-ignored `.env`). Keep keys
  out of git here too (`--dart-define` / untracked config). The picker must fall back to a
  list when the map fails.
- The cloud sandbox can't reach Yandex or run Android/iOS builds; don't try to verify maps or
  device UI there. Verify with analyze + unit/widget tests and say what was not run.
