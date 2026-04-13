# RUN LOG — TASK-019

**Date:** 2026-03-30
**Phase:** 3
**Status:** COMPLETE

---

## SUMMARY

Standardized package naming from `@qrv/` → `@qrvee/` across the entire
monorepo. Updated 56 TypeScript/TSX import files, all package.json files,
all tsconfig path mappings, next.config.mjs, and vendor/shared-lib.
Fixed a pre-existing import path bug in broadcast.tsx discovered during
mobile TS validation. All three build targets: zero errors.

---

## PART 1 — DETECTION RESULTS

### Rename scope (changed)

| Category | Count | From → To |
|----------|-------|-----------|
| Root package name | 1 | `qrv` → `qrvee` |
| Functions package name | 1 | `qrv-functions` → `wavl-functions` |
| Web package name | 1 | `@qrv/web` → `@qrvee/web` |
| Mobile package name | 1 | `@qrv/mobile` → `@qrvee/mobile` |
| `@qrv/shared` package name | 2 | packages/shared + vendor/shared-lib |
| `@qrv/shared` dependency | 3 | web, mobile, functions package.json |
| tsconfig path mappings | 3 | web, mobile, functions tsconfig.json |
| next.config.mjs transpilePackages | 1 | `@qrv/shared` |
| TS/TSX import statements | 56 files | `'@qrv/shared'` → `'@qrvee/shared'` |

### Intentionally NOT renamed

| Category | Reason |
|----------|--------|
| Tailwind color tokens (`qrv-*`) | Design system tokens — 450+ class usages; renaming is a visual-layer refactor, not a naming inconsistency |
| i18n key `broadcast.youAreQrv` / `"YOU ARE QRV"` | "QRV" is a ham radio Q-code (ITU standard), not the app name |
| `app.qrv.ee` / `bundleIdentifier` | Domain-based identifier — changing requires Play Store / App Store migration |
| `qrv.ee` / `callsign@qrv.ee` domain refs | Domain, correct as-is |

---

## PART 2 — FILES CHANGED

### Package names
- `package.json`: `"name": "qrv"` → `"qrvee"`
- `apps/web/package.json`: `"name": "@qrv/web"` → `"@qrvee/web"`; dep `@qrv/shared` → `@qrvee/shared`
- `apps/mobile/package.json`: `"name": "@qrv/mobile"` → `"@qrvee/mobile"`; dep → updated
- `firebase/functions/package.json`: `"name": "qrv-functions"` → `"wavl-functions"`; dep → updated
- `packages/shared/package.json`: `"name": "@qrv/shared"` → `"@qrvee/shared"`
- `firebase/functions/vendor/shared-lib/package.json`: `"name": "@qrv/shared"` → `"@qrvee/shared"`

### TypeScript config
- `apps/web/tsconfig.json`: paths `@qrv/shared` → `@qrvee/shared`
- `apps/mobile/tsconfig.json`: paths `@qrv/shared` → `@qrvee/shared`
- `firebase/functions/tsconfig.json`: paths `@qrv/shared` → `@qrvee/shared`
- `apps/web/next.config.mjs`: transpilePackages `@qrv/shared` → `@qrvee/shared`

### TypeScript source (bulk sed replacement)
- 56 .ts/.tsx files with `from '@qrv/shared'` or `from '@qrv/shared/...'` imports updated

### Bug fixed (pre-existing, discovered during mobile build)
- `apps/mobile/app/(tabs)/broadcast.tsx` line 12:
  - Wrong: `'../../../src/lib/events/qrveeEvents'` (3 levels up → outside package)
  - Fixed: `'../../src/lib/events/qrveeEvents'` (2 levels up → correct)
- Same file line 115: added `if (user)` guard before `user.uid` access (TS18047)

---

## PART 3 — BUILD RESULTS

| Target | Result |
|--------|--------|
| `firebase/functions` (tsc) | ✓ Zero errors |
| `apps/web` (tsc --noEmit) | ✓ Zero errors |
| `apps/mobile` (tsc --noEmit) | ✓ Zero errors |

Post-rename grep for `@qrv/shared` in source (excluding node_modules, .next, .expo):
```
(no output — zero remaining occurrences)
```

---

## PART 4 — DEPLOY SAFETY

- `vendor/shared-lib/package.json` updated to `@qrvee/shared` — Cloud Build will resolve correctly
- `firebase/functions/package.json` dependency updated to `"@qrvee/shared": "file:./vendor/shared-lib"`
- `firebase/functions/tsconfig.json` paths updated — tsc resolves correctly
- No deployed CF names changed — `onQrveeEventCreated`, `onPnotEventCreated`, etc. unchanged
- No Firestore collection names changed — `events_qrvee`, `event_processing` unchanged
