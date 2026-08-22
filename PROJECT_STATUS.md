# ChronOS — Project Status

**Last updated:** 2026-08-22
**Current phase:** Milestone 1 (MVP) complete
**Current milestone:** Milestone 2 (Comparison & polish) is next (`PRD.md` §9)

> This file is a living snapshot, updated as work happens — it shows where the project stands *right now*. For the full history of changes, see `CHANGELOG.md`. For what's planned, see `PRD.md` §9 (milestones).

---

## 1. At a glance

| | |
|---|---|
| Time elapsed | Milestone 0 + 1 of 4–6 weeks |
| Milestone | Milestone 1 (MVP) complete — Milestone 2 next |
| Engine | Working — FCFS, SJF, RR, Priority, AARS all implemented, built, and verified |
| Dashboard | Working — full EDRD.md spec, verified against real engine output in-browser |
| Analysis | Not started (Milestone 2 scope) |
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
- [x] Milestone 0 (Setup): toolchain, folder scaffold, `Process`/`State`/`ProcessClass`, fake `results.json`, dashboard skeleton rendering it
- [x] Milestone 1 (MVP): simulator core, all 5 schedulers (FCFS/SJF/RR/Priority/AARS), full dashboard, 2 workload presets — see `CHANGELOG.md` `[Unreleased]` for details

## 3. What's in progress

Nothing — between milestones.

## 4. What's next (Milestone 2 — Comparison & polish, `PRD.md` §9)

- [ ] `analysis/analysis.py`: read multiple result JSONs, build comparison table, generate the 4 charts from PRD §8.2
- [ ] Remaining workload presets: `mixed`, `starvation` stress test
- [ ] Retune AARS thresholds (PRD §6.2/6.3) against real data — see open question below, already known to matter
- [ ] Basic logging cleanup if anything's missing beyond the existing `decisionLog`/`scheduler.log`

---

## 5. Milestone tracker

| Milestone | Target | Status | Notes |
|---|---|---|---|
| 0 — Setup | Week 1 (~2–3 days) | Done | |
| 1 — MVP (FCFS, SJF, RR, Priority, AARS + dashboard) | End of week 3 | Done | |
| 2 — Comparison & polish | End of week 4 | Not started | |
| 3 — MLFQ + depth | End of week 5 (if time allows) | Not started | |
| 4 — Stretch goals + presentation prep | Week 6 (optional) | Not started | |

## 6. Component status

| Component | Status | Notes |
|---|---|---|
| `engine/process.h/.cpp` | Done | |
| `engine/behavior_analyzer.*` | Done | |
| `engine/schedulers/fcfs.cpp` | Done | |
| `engine/schedulers/sjf.cpp` | Done | |
| `engine/schedulers/round_robin.cpp` | Done | |
| `engine/schedulers/priority.cpp` | Done | fixed-interval aging, +1 per 5 ticks waited |
| `engine/schedulers/aars.cpp` | Done | full §6.1–6.4 formula, honest weights, not retuned |
| `engine/schedulers/mlfq.cpp` | Not started (Milestone 3) | |
| `engine/simulator.*` | Done | |
| `dashboard/index.html` / `style.css` / `app.js` | Done | |
| `analysis/analysis.py` | Not started (Milestone 2) | |
| `workloads/*.json` presets | 2 of 4 done | `cpu_heavy`, `interactive` done; need `mixed`, `starvation` |
| `CMakeLists.txt` | Done | |

---

## 7. Open questions / decisions pending

Carried from `PRD.md` §14 — revisit once real data exists:

- [ ] Do the AARS weight thresholds (`PRD.md` §6.2/6.3) actually separate workloads well, or do they need retuning? **Now has real data**: both Milestone-1 presets classify almost entirely `UNKNOWN` in practice — not a mechanism bug (verified working via a scratch contention test), but because avgBurst tends to land between the IO/interactive threshold (4) and the CPU-bound threshold (15), given AARS's own quantum table caps most recorded bursts at 2–8. This is the first concrete candidate for Milestone 2 retuning.
- [ ] Is the 4–6 week estimate holding once Milestone 0/1 actual time-spent is known?
- [ ] Which single stretch goal (`PRD.md` §6.5), if any, is worth pursuing in Milestone 4?

## 8. Blockers

None currently.

## 9. Known risks being watched

See `PRD.md` §13 for full list. Top of mind right now:

- MLFQ complexity, if/when Milestone 3 is reached
- AARS classification thresholds vs. its own quantum table (see open question above) — top priority for Milestone 2's retuning pass

---

## How to update this file

After finishing a milestone task or hitting a blocker: move the item from §4 to §2, update §5/§6 status columns, bump "Last updated," and add the corresponding entry to `CHANGELOG.md` under `[Unreleased]`. Keep this file short and current — it's a status snapshot, not a log; history belongs in `CHANGELOG.md`.
