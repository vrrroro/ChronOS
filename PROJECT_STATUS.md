# ChronOS — Project Status

**Last updated:** 2026-08-22
**Current phase:** Planning complete — implementation not started
**Current milestone:** Pre-Milestone 0 (`PRD.md` §9)

> This file is a living snapshot, updated as work happens — it shows where the project stands *right now*. For the full history of changes, see `CHANGELOG.md`. For what's planned, see `PRD.md` §9 (milestones).

---

## 1. At a glance

| | |
|---|---|
| Time elapsed | 0 of 4–6 weeks |
| Milestone | Not started — Milestone 0 (Setup) is next |
| Engine | Not started |
| Dashboard | Not started |
| Analysis | Not started |
| Blockers | None |
| Docs | Complete — `PRD.md`, `EDRD.md`, `ARCHITECTURE.md`, `CLAUDE.md`, `CHANGELOG.md` |

---

## 2. What's done

- [x] Project scoped and de-risked for a solo 4–6 week beginner build (`PRD.md`)
- [x] Dashboard visual/interaction design specified (`EDRD.md`)
- [x] System architecture, module boundaries, and data contracts specified (`ARCHITECTURE.md`)
- [x] AI-assisted build rules and constraints documented (`CLAUDE.md`)
- [x] Project renamed ChronosOS → ChronOS across all docs
- [x] Change history established (`CHANGELOG.md`)

## 3. What's in progress

Nothing yet.

## 4. What's next (Milestone 0 — Setup, `PRD.md` §9)

- [ ] Install toolchain: g++, cmake, python3, matplotlib, pandas, git
- [ ] Scaffold folder structure per `ARCHITECTURE.md` §1 / `PRD.md` §4.2, init git repo, first commit
- [ ] Write `Process` struct + `State` enum (`PRD.md` §5.1) — no scheduling logic yet
- [ ] Hand-write one fake `results.json` (`PRD.md` §5.3) and get the dashboard skeleton rendering it, before any real engine code exists

---

## 5. Milestone tracker

| Milestone | Target | Status | Notes |
|---|---|---|---|
| 0 — Setup | Week 1 (~2–3 days) | Not started | |
| 1 — MVP (FCFS, SJF, RR, Priority, AARS + dashboard) | End of week 3 | Not started | |
| 2 — Comparison & polish | End of week 4 | Not started | |
| 3 — MLFQ + depth | End of week 5 (if time allows) | Not started | |
| 4 — Stretch goals + presentation prep | Week 6 (optional) | Not started | |

## 6. Component status

| Component | Status | Notes |
|---|---|---|
| `engine/process.h/.cpp` | Not started | |
| `engine/behavior_analyzer.*` | Not started | |
| `engine/schedulers/fcfs.cpp` | Not started | |
| `engine/schedulers/sjf.cpp` | Not started | |
| `engine/schedulers/round_robin.cpp` | Not started | |
| `engine/schedulers/priority.cpp` | Not started | |
| `engine/schedulers/aars.cpp` | Not started | |
| `engine/schedulers/mlfq.cpp` | Not started (Milestone 3) | |
| `engine/simulator.*` | Not started | |
| `dashboard/index.html` / `style.css` / `app.js` | Not started | |
| `analysis/analysis.py` | Not started | |
| `workloads/*.json` presets | Not started | Need: CPU-heavy, interactive, mixed, starvation |
| `CMakeLists.txt` | Not started | |

---

## 7. Open questions / decisions pending

Carried from `PRD.md` §14 — revisit once real data exists:

- [ ] Do the AARS weight thresholds (`PRD.md` §6.2/6.3) actually separate workloads well, or do they need retuning?
- [ ] Is the 4–6 week estimate holding once Milestone 0/1 actual time-spent is known?
- [ ] Which single stretch goal (`PRD.md` §6.5), if any, is worth pursuing in Milestone 4?

## 8. Blockers

None currently.

## 9. Known risks being watched

See `PRD.md` §13 for full list. Top of mind right now:

- MLFQ complexity, if/when Milestone 3 is reached
- AARS formula separating process classes cleanly once real burst data exists

---

## How to update this file

After finishing a milestone task or hitting a blocker: move the item from §4 to §2, update §5/§6 status columns, bump "Last updated," and add the corresponding entry to `CHANGELOG.md` under `[Unreleased]`. Keep this file short and current — it's a status snapshot, not a log; history belongs in `CHANGELOG.md`.
