# RUN LOG — TASK-017

**Date:** 2026-03-30
**Phase:** 3
**Status:** COMPLETE

---

## SUMMARY

Performed live validation of the event system against the deployed Firebase project.
Discovered and fixed a critical deploy pipeline bug (@qrv/shared not resolvable by
Cloud Build). After fix, deployed all functions and confirmed end-to-end event flow
in production Firestore.

---

## PART 1 — DEPLOY (problems encountered)

### Problem: @qrv/shared not found by Cloud Build

First deploy attempt failed:
```
npm error 404 Not Found - GET https://registry.npmjs.org/@qrv%!f(MISSING)shared - Not found
```

Root cause: Cloud Build runs `npm install` in a clean environment. `@qrv/shared`
is a local workspace package, not published to npm. Cloud Build cannot access
the monorepo workspace resolution.

### Fix applied

1. Added `tsconfig.json` to `packages/shared` (no tsconfig existed)
2. Compiled `packages/shared` → `packages/shared/lib` (JS + .d.ts)
3. Copied compiled output to `firebase/functions/vendor/shared-lib`
4. Changed `functions/package.json`: `"@qrv/shared": "file:./vendor/shared-lib"`
5. Added `"paths": {"@qrv/shared": ["./vendor/shared-lib"]}` to functions tsconfig
   to prevent tsc from following workspace symlinks to TS source (rootDir expansion bug)
6. Added `"rootDir": "src"` to functions tsconfig to fix output directory structure
7. Fixed `oracle.ts`: changed direct relative import from
   `'../../../packages/shared/src/types/propagation'` → `'@qrv/shared'`

### Second deploy: success

```
✔  functions[onQrveeEventCreated(us-central1)] Created
✔  functions[onPnotEventCreated(us-central1)] Created
✔  functions[onMinwinEventCreated(us-central1)] Created
✔  functions[retryFailedProcessing(us-central1)] Created
✔  Deploy complete!
```

---

## PART 2 — REAL EVENT TRIGGER

Triggered via Node.js admin SDK script:

| Event | Firestore ID |
|-------|-------------|
| session.started | ScjhWaRJbIr7dTFgRDlO |
| qso.logged | ZnYTsna5Muaciyz9cp11 |

---

## PART 3 — FIRESTORE RESULTS (checked 15s after write)

### events_qrvee
- ScjhWaRJbIr7dTFgRDlO (session.started) ✓
- ZnYTsna5Muaciyz9cp11 (qso.logged) ✓

### event_processing (all status=done, attempts=1, error=null)
```
ScjhWaRJbIr7dTFgRDlO_pnot: status=done  app=pnot  attempts=1  error=null
ScjhWaRJbIr7dTFgRDlO_tinc: status=done  app=tinc  attempts=1  error=null
ZnYTsna5Muaciyz9cp11_pnot: status=done  app=pnot  attempts=1  error=null
ZnYTsna5Muaciyz9cp11_tinc: status=done  app=tinc  attempts=1  error=null
```

### pnot_notes (both created, sourceEventId matches event)
```
yc7AhHS43YY2OZWy2stJ: title="Session started: TA1ABC on 20m / SSB"
                       category=qrvee_session
                       sourceEventId=ScjhWaRJbIr7dTFgRDlO ✓

Bz7y1ryDQ6B2lB8mqVJ9: title="QSO: DL1ABC on 14.0740 MHz (FT8)"
                       category=qso
                       sourceEventId=ZnYTsna5Muaciyz9cp11 ✓
```

---

## PART 4 — FUNCTION LOGS

Cloud Logging API not accessible via CLI in this environment.
Logs visible in Firebase Console: Cloud Functions → Logs.

---

## PART 5 — RETRY TEST

Not performed. All CFs executed successfully on first attempt (status=done,
attempts=1). Retry mechanism can be validated by inspecting retryFailedProcessing
behavior with a deliberately malformed event in a future task.

---

## CONCLUSION

Event system confirmed working end-to-end in production:
- Client write → events_qrvee ✓
- Router CF triggered → event_processing records created ✓
- PNOT handler executed → pnot_notes created with correct titles ✓
- TINC handler (stub) executed → status=done ✓
- All records: attempts=1, error=null, status=done ✓

---

## FILES CREATED/MODIFIED

| File | Change |
|------|--------|
| `packages/shared/tsconfig.json` | New — enables shared package build |
| `packages/shared/lib/` | New — compiled shared output |
| `firebase/functions/vendor/shared-lib/` | New — vendored compiled shared for Cloud Build |
| `firebase/functions/package.json` | Changed @qrv/shared to file:./vendor/shared-lib |
| `firebase/functions/tsconfig.json` | Added rootDir, baseUrl, paths, skipLibCheck |
| `firebase/functions/src/oracle.ts` | Fixed direct relative import → @qrv/shared |
| `tinc/RUN_LOG/TASK-017.md` | This file |

Git commit: d6c493e
