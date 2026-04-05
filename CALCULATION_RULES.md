# CALCULATION RULES

All derived values must be deterministic. No approximations. (LAW-007)

---

## Session Duration

```
durationMinutes = FLOOR((QSO_END.serverTime - Session.startedAt) / 60000)
minimum: 0
type: integer
```

---

## OperatorState.lastSeenAt

```
lastSeenAt = MAX(
  last QSO_END.serverTime for this userId,
  last USER_OFFLINE.serverTime for this userId
)
```

---

## WorkItem Derived Values

**duration** (milliseconds):
```
duration = WorkItem.endAt.toMillis() - WorkItem.startAt.toMillis()
type: integer, always > 0 (guaranteed by V-W2)
```

**progressRate** (progress points per millisecond):
```
progressRate = WorkItem.progress / duration
type: float
precondition: duration > 0 (always true by V-W2)
```

**isActive** (boolean, derived on read):
```
isActive = (WorkItem.status == ACTIVE)
        AND (serverTime >= WorkItem.startAt)
        AND (serverTime <= WorkItem.endAt)
type: boolean
never stored — computed at read time
```

---

## Live Aggregations (derived on read, never stored)

| Value | Formula |
|-------|---------|
| activeOperatorCount | COUNT(OperatorState WHERE online = true) |
| activeRegions | DISTINCT(Session.continent WHERE active = true) |
| activeRegionCount | COUNT(activeRegions) |
| qsoCountLast24h | COUNT(QSO WHERE createdAt > NOW - 86400000ms) |
| sessionCountLive | COUNT(Session WHERE active = true) |
| workItemsActive | COUNT(WorkItem WHERE status = ACTIVE) |
| workItemsBlocked | COUNT(WorkItem WHERE status = BLOCKED) |

---

## Rules

- All counts: INTEGER — no decimals
- All times: UTC Timestamp — no local time
- All durations: integer milliseconds (WorkItem) or integer minutes (Session)
- Session durations: FLOOR, never CEIL or ROUND
- Aggregations computed at query time — not cached in documents
- NOW = server Timestamp at time of read
- progressRate: float, NOT stored, computed on demand only
