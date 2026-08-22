// ChronOS dashboard — ARCHITECTURE.md §5.2-5.3 state model.
//
// decisionLog candidates carry {pid, score, priority, burstRemaining, class}
// (PRD.md §5.3, extended at integration time — see its "Integration-time
// addition" note). priority/class are read straight off the candidate for
// the ready queue table; burstRemaining is instead computed live from Gantt
// history up to the currently-viewed tick, since the candidate's own
// burstRemaining is only a snapshot as of its decision tick, which can be
// earlier than the tick currently being scrubbed to.

(function () {
  'use strict';

  // Single source of truth — the only thing that changes during playback
  // is currentTick/isPlaying/speed. Every panel is a pure function of this.
  const state = {
    resultData: null,
    currentTick: 0,
    isPlaying: false,
    speed: 1,
  };

  // Animation/session bookkeeping — NOT part of the render-determinism
  // contract above (render(state) is still correct for any state value on
  // its own), just transient UI polish that needs "did this change since
  // last frame" info a pure function of state alone can't express cleanly.
  let intervalId = null;
  let lastRunningPid = null;
  let agingFlashed = new Set();   // pids already flashed this session
  let agingAboveThreshold = new Map(); // pid -> bool, last known state

  const BASE_TICKS_PER_SECOND = 2;
  const AGING_WARNING_THRESHOLD = 8; // EDRD §5.5 example threshold

  const $ = (id) => document.getElementById(id);

  // ---------------------------------------------------------------
  // GSAP enhancements — logged exception to "no animation library"
  // (CLAUDE.md Dashboard rules / EDRD §8.3). Scoped to exactly 4 moments:
  // panel load-in, stat-tile counters, hover lift, playhead motion. Every
  // call is guarded by `typeof gsap === 'undefined'` so the dashboard still
  // renders correctly (just without the extra polish) if vendor/gsap.min.js
  // ever fails to load — render(state) itself never depends on GSAP.
  // ---------------------------------------------------------------

  const HAS_GSAP = typeof gsap !== 'undefined';
  const HAS_SCROLLTRIGGER = HAS_GSAP && typeof ScrollTrigger !== 'undefined';
  if (HAS_SCROLLTRIGGER) gsap.registerPlugin(ScrollTrigger);

  // Stagger-reveal a set of panels — EDRD §6.7: fast, restrained, only on a
  // genuine load (page boot, or a new result JSON), never on playback.
  function animateLoadIn(selector) {
    const els = HAS_GSAP ? gsap.utils.toArray(selector) : [];
    if (!els.length) return;
    gsap.fromTo(els, { opacity: 0, y: 8 }, { opacity: 1, y: 0, duration: 0.3, stagger: 0.04, ease: 'power1.out', overwrite: true });
  }

  // Count-up/down tween for a stat tile — target overwrites the running
  // tween automatically (GSAP default), so rapid tick-by-tick updates
  // during playback chase smoothly instead of queuing up.
  const counterProxies = { cpu: { value: 0 }, processes: { value: 0 }, switches: { value: 0 } };
  function animateCounter(proxy, el, newValue, suffix) {
    if (!HAS_GSAP) { el.textContent = Math.round(newValue) + (suffix || ''); return; }
    gsap.to(proxy, {
      value: newValue,
      duration: 0.25,
      ease: 'power1.out',
      onUpdate: () => { el.textContent = Math.round(proxy.value) + (suffix || ''); },
    });
  }

  // Subtle hover lift (EDRD-compatible: 1px, 150ms, power1.out — matches
  // the existing CSS hover treatments' timing, just adds a motion cue on
  // top of the color/opacity ones CSS already owns).
  function attachHoverLift(el) {
    if (!HAS_GSAP) return;
    el.addEventListener('mouseenter', () => gsap.to(el, { y: -1, duration: 0.15, ease: 'power1.out', overwrite: true }));
    el.addEventListener('mouseleave', () => gsap.to(el, { y: 0, duration: 0.15, ease: 'power1.out', overwrite: true }));
  }

  // Playhead: quickTo (linear, tied to tick rate) during continuous
  // playback so motion reads as smooth per EDRD §6.1; gsap.set (truly
  // instant, no tween) for manual scrub/step/reset per the same section's
  // "a dragged scrub bar that eases toward your cursor feels laggy" rule.
  let playheadQuickTo = null;
  function movePlayhead(pxLeft, animate) {
    const playhead = $('gantt-playhead');
    if (!HAS_GSAP) { playhead.style.left = `${pxLeft}px`; return; }
    if (animate) {
      if (!playheadQuickTo) playheadQuickTo = gsap.quickTo(playhead, 'left', { duration: 1 / (BASE_TICKS_PER_SECOND * state.speed), ease: 'none' });
      playheadQuickTo(pxLeft);
    } else {
      gsap.killTweensOf(playhead);
      gsap.set(playhead, { left: pxLeft });
    }
  }

  // Intro hero — CRT-boot wordmark flicker-in (time-based, plays once on
  // load), then a real scroll-driven exit: scrolling through the hero's
  // one-viewport height pins it and scrubs the wordmark/scanline out,
  // revealing the dashboard underneath. Skippable via click/keypress
  // (smooth-scrolls straight past the hero — still scroll-driven, just
  // fast-forwarded) and respects prefers-reduced-motion (no pin/scrub,
  // hero behaves as a plain static section). `onComplete` fires exactly
  // once, the first time the hero is scrolled past, and is where the
  // dashboard's own boot reveal (animateLoadIn) picks up.
  function initIntro(onComplete) {
    const hero = $('intro-hero');
    const app = $('app');
    if (!hero) { onComplete(); return; }

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!HAS_GSAP || !HAS_SCROLLTRIGGER || reduced) {
      // No pin/scrub/flicker — just make the hero's text immediately
      // readable (plain DOM, no GSAP dependency) and let the dashboard
      // boot in underneath; the user scrolls past the static hero normally.
      hero.querySelector('.intro-wordmark').style.opacity = '1';
      $('intro-subtitle').style.opacity = '1';
      $('intro-skip-hint').style.opacity = '1';
      onComplete();
      return;
    }

    const wordmark = hero.querySelector('.intro-wordmark');
    const subtitle = $('intro-subtitle');
    const scan = $('intro-scanline');
    const hint = $('intro-skip-hint');

    // Entrance: plays immediately on load, independent of scroll.
    gsap.timeline()
      .to(wordmark, { opacity: 1, duration: 0.05 })
      .to(wordmark, { opacity: 0.15, duration: 0.03 })
      .to(wordmark, { opacity: 0.85, duration: 0.04 })
      .to(wordmark, { opacity: 0.1, duration: 0.03 })
      .to(wordmark, { opacity: 1, duration: 0.2, ease: 'power1.out' })
      .to(subtitle, { opacity: 1, duration: 0.3, ease: 'power1.out' }, '-=0.05')
      .to(hint, { opacity: 1, duration: 0.3, ease: 'power1.out', onComplete: () => hint.classList.add('is-visible') });

    let revealed = false;
    function reveal() {
      if (revealed) return;
      revealed = true;
      window.removeEventListener('keydown', skip);
      hero.removeEventListener('click', skip);
      onComplete();
    }

    // Exit: scrubbed by real scroll position through the hero's own
    // height, then pin releases and the dashboard (`#app`) takes over the
    // viewport normally — the one place in the app that scrolls (EDRD §4.1
    // logged exception), the dashboard itself still needs none once reached.
    const exitTl = gsap.timeline({
      scrollTrigger: {
        trigger: hero,
        start: 'top top',
        end: 'bottom top',
        scrub: 0.5,
        pin: true,
        onLeave: reveal, // fires once per page load — scrolling back up and down again re-pins/re-scrubs visually but doesn't replay the dashboard's own boot reveal a second time
      },
    })
      .to(wordmark, { scale: 0.6, opacity: 0, ease: 'none' })
      .to(subtitle, { opacity: 0, ease: 'none' }, '<')
      .to(hint, { opacity: 0, ease: 'none' }, '<')
      .to(scan, { top: '100%', opacity: 1, ease: 'none' }, '<')
      .to(hero, { opacity: 0, ease: 'none' }, '<0.3');

    // `hero.offsetHeight` alone is NOT the right skip target — ScrollTrigger's
    // `pin: true` inserts spacer space to hold the pin's whole scroll range,
    // so the dashboard's actual document position is `hero height + pin
    // range` further down, not just past the hero itself. Landing short of
    // that leaves the viewport in the dead zone between "hero faded out" and
    // "dashboard not yet scrolled into view" — go to the trigger's own
    // resolved `end` (its absolute page scroll position) instead.
    function skip() {
      const st = exitTl.scrollTrigger;
      window.scrollTo({ top: st ? st.end : hero.offsetHeight, behavior: 'smooth' });
    }
    hero.addEventListener('click', skip);
    window.addEventListener('keydown', skip);
  }

  // ---------------------------------------------------------------
  // Derivation helpers (schema-gap workarounds, see note above)
  // ---------------------------------------------------------------

  function maxTick(data) {
    let m = 0;
    for (const g of data.gantt || []) m = Math.max(m, g.end);
    for (const p of data.processStats || []) m = Math.max(m, p.completionTime || 0);
    return m;
  }

  // pid -> { arrivalTime, burstTime, waitingTimeFinal, turnaroundTime, responseTime, completionTime }
  function buildProcessMeta(data) {
    const meta = {};
    for (const p of data.processStats || []) {
      const burstTime = p.turnaroundTime - p.waitingTime;
      const arrivalTime = p.completionTime - p.turnaroundTime;
      meta[p.pid] = {
        arrivalTime,
        burstTime,
        waitingTimeFinal: p.waitingTime,
        turnaroundTime: p.turnaroundTime,
        responseTime: p.responseTime,
        completionTime: p.completionTime,
      };
    }
    return meta;
  }

  function ticksRunUpTo(data, pid, tick) {
    let sum = 0;
    for (const g of data.gantt || []) {
      if (g.pid !== pid) continue;
      const overlap = Math.max(0, Math.min(g.end, tick) - g.start);
      sum += overlap;
    }
    return sum;
  }

  function cpuBusyTicksUpTo(data, tick) {
    let sum = 0;
    for (const g of data.gantt || []) {
      sum += Math.max(0, Math.min(g.end, tick) - Math.min(g.start, tick));
    }
    return sum;
  }

  function runningSegmentAt(data, tick) {
    for (const g of data.gantt || []) {
      if (tick >= g.start && tick < g.end) return g;
    }
    return null;
  }

  function lastDecisionAt(data, tick) {
    let found = null;
    for (const d of data.decisionLog || []) {
      if (d.tick <= tick) found = d;
      else break;
    }
    return found;
  }

  function contextSwitchesUpTo(data, tick) {
    const log = (data.decisionLog || []).filter((d) => d.tick <= tick);
    let switches = 0;
    for (let i = 1; i < log.length; i++) {
      if (log[i].chosen !== log[i - 1].chosen) switches++;
    }
    return switches;
  }

  function completedCountUpTo(data, tick) {
    return (data.processStats || []).filter((p) => p.completionTime <= tick).length;
  }

  // Aging bonus recomputed via the PRD §6.2 starting formula (min(wait/2,10)).
  // NOTE: if the engine's tuned weights differ from this starting value
  // (CLAUDE.md explicitly allows deliberate retuning), this display value
  // can drift from the engine's authoritative score — flagged in report.
  function estimateAgingBonus(waitingTimeSoFar) {
    return Math.min(waitingTimeSoFar / 2, 10);
  }

  function processColor(pid) {
    const idx = ((pid % 8) + 8) % 8; // palette[pid % 8], 0-indexed slot -> --proc-(idx+1)
    return `var(--proc-${idx + 1})`;
  }

  function humanizeReasonTag(tag, candidates) {
    const m = tag.match(/^([a-z_]+):([+-][\d.]+)$/i);
    if (m) {
      const label = m[1].replace(/_/g, ' ').toUpperCase();
      const val = parseFloat(m[2]);
      const sign = val >= 0 ? '+' : '−';
      const arrow = val >= 0 ? '▲' : '▼';
      return { text: `${label}: `, delta: `${sign}${Math.abs(val)} ${arrow}`, positive: val >= 0 };
    }
    if (tag === 'only_candidate') return { text: 'Only ready process — no other candidates this decision', delta: null };
    if (tag === 'highest_score') {
      if (candidates && candidates.length > 1) {
        const sorted = [...candidates].sort((a, b) => b.score - a.score);
        return { text: `Highest adaptive score (${sorted[0].score.toFixed(1)} vs next-best ${sorted[1].score.toFixed(1)})`, delta: null };
      }
      return { text: 'Highest adaptive score', delta: null };
    }
    return { text: tag.replace(/_/g, ' '), delta: null };
  }

  // ---------------------------------------------------------------
  // Rendering — render(state) is a pure function of state + resultData
  // ---------------------------------------------------------------

  function render(s) {
    const data = s.resultData;
    if (!data) {
      renderEmptyShell();
      return;
    }
    $('empty-state').hidden = true;
    $('main-grid-inner').hidden = false;

    const meta = buildProcessMeta(data);
    const mt = maxTick(data);

    renderTopBar(s, data, mt);
    renderGanttChart(s, data, mt);
    renderReadyQueue(s, data, meta);
    renderWhyPanel(s, data);
    renderAgingList(s, data, meta);
    renderPlaybackUI(s, mt);
  }

  function renderEmptyShell() {
    $('empty-state').hidden = false;
    $('main-grid-inner').hidden = true;
    const pill = $('status-pill');
    pill.className = 'status-pill is-idle-empty';
    $('status-text').textContent = 'NO SIMULATION LOADED';
  }

  function renderTopBar(s, data, mt) {
    $('run-algorithm').textContent = data.algorithm || '—';
    $('run-workload').textContent = data.workloadName || '—';

    const busy = cpuBusyTicksUpTo(data, s.currentTick);
    const util = s.currentTick > 0 ? Math.round((busy / s.currentTick) * 100) : 0;
    animateCounter(counterProxies.cpu, $('stat-cpu'), util, '%');
    $('stat-cpu-bar').style.width = `${util}%`;
    animateCounter(counterProxies.processes, $('stat-processes'), (data.processStats || []).length, '');
    animateCounter(counterProxies.switches, $('stat-switches'), contextSwitchesUpTo(data, s.currentTick), '');

    const pill = $('status-pill');
    if (s.isPlaying) {
      pill.className = 'status-pill is-playing';
      $('status-text').textContent = 'PLAYING';
    } else {
      pill.className = 'status-pill';
      pill.style.color = 'var(--state-ready)';
      $('status-text').textContent = 'SIMULATION LOADED';
    }
  }

  function renderGanttChart(s, data, mt) {
    const track = $('gantt-track');
    // Rebuild segments (keep playhead element, it's created once)
    track.querySelectorAll('.gantt-segment, .gantt-idle').forEach((el) => el.remove());

    const pxPerTick = 24;
    track.style.width = `${Math.max(mt * pxPerTick, 400)}px`;

    let cursor = 0;
    const segs = [...(data.gantt || [])].sort((a, b) => a.start - b.start);
    for (const g of segs) {
      if (g.start > cursor) {
        const idle = document.createElement('div');
        idle.className = 'gantt-idle';
        idle.style.left = `${cursor * pxPerTick}px`;
        idle.style.width = `${(g.start - cursor) * pxPerTick}px`;
        track.appendChild(idle);
      }
      const el = document.createElement('div');
      const isRunningNow = s.currentTick >= g.start && s.currentTick < g.end;
      el.className = 'gantt-segment' + (isRunningNow ? ' is-running' : '');
      el.style.left = `${g.start * pxPerTick}px`;
      el.style.width = `${(g.end - g.start) * pxPerTick}px`;
      const color = processColor(g.pid);
      el.style.background = color;
      el.style.borderColor = color;
      el.style.color = 'var(--text-on-accent)';
      if (isRunningNow) el.style.color = color;
      if (g.end - g.start >= 32 / pxPerTick) {
        el.textContent = `P${g.pid}`;
      }
      el.addEventListener('mouseenter', (ev) => showGanttTooltip(ev, g));
      el.addEventListener('mousemove', (ev) => showGanttTooltip(ev, g));
      el.addEventListener('mouseleave', hideGanttTooltip);
      attachHoverLift(el);
      track.appendChild(el);
      cursor = g.end;
    }
    if (cursor < mt) {
      const idle = document.createElement('div');
      idle.className = 'gantt-idle';
      idle.style.left = `${cursor * pxPerTick}px`;
      idle.style.width = `${(mt - cursor) * pxPerTick}px`;
      track.appendChild(idle);
    }

    // Playhead — smooth (GSAP quickTo) during continuous playback, instant
    // (gsap.set) on manual scrub/step/pause/reset, per EDRD §6.1.
    movePlayhead(s.currentTick * pxPerTick, s.isPlaying);

    // Ruler
    const ruler = $('gantt-ruler');
    ruler.innerHTML = '';
    ruler.style.width = `${Math.max(mt * pxPerTick, 400)}px`;
    const step = mt > 60 ? 10 : mt > 24 ? 5 : 2;
    for (let t = 0; t <= mt; t += step) {
      const mark = document.createElement('span');
      mark.className = 'gantt-tick-mark';
      mark.style.left = `${t * pxPerTick}px`;
      mark.textContent = String(t);
      ruler.appendChild(mark);
    }

    // Context-switch crossfade cue (EDRD §6.2) — best-effort, non-essential polish
    const runningSeg = runningSegmentAt(data, s.currentTick);
    const runningPid = runningSeg ? runningSeg.pid : null;
    if (runningPid !== lastRunningPid) {
      lastRunningPid = runningPid;
    }
  }

  function showGanttTooltip(ev, g) {
    const tip = $('gantt-tooltip');
    tip.hidden = false;
    tip.textContent = `P${g.pid} · ${g.start}–${g.end} ticks · duration ${g.end - g.start} · ${g.reason || ''}`;
    const wrap = $('gantt-scroll').getBoundingClientRect();
    tip.style.left = `${ev.clientX - wrap.left + 8}px`;
    tip.style.top = `${ev.clientY - wrap.top - 32}px`;
  }
  function hideGanttTooltip() {
    $('gantt-tooltip').hidden = true;
  }

  function renderReadyQueue(s, data, meta) {
    const isAars = (data.algorithm || '').toUpperCase() === 'AARS';
    $('col-score').style.display = isAars ? '' : 'none';

    const decision = lastDecisionAt(data, s.currentTick);
    const tbody = $('ready-queue-body');
    tbody.innerHTML = '';

    if (!decision) {
      $('ready-queue-empty').hidden = false;
      tbody.parentElement.hidden = true;
      return;
    }

    const runningSeg = runningSegmentAt(data, s.currentTick);
    const runningPid = runningSeg ? runningSeg.pid : null;

    let rows = decision.candidates
      .filter((c) => {
        const m = meta[c.pid];
        return m && m.arrivalTime <= s.currentTick && m.completionTime > s.currentTick;
      })
      .map((c) => {
        const m = meta[c.pid];
        const ranSoFar = ticksRunUpTo(data, c.pid, s.currentTick);
        const waitSoFar = Math.max(0, s.currentTick - m.arrivalTime - ranSoFar);
        return {
          pid: c.pid,
          score: c.score,
          priority: c.priority !== undefined ? c.priority : null,
          burstRemaining: m.burstTime - ranSoFar,
          wait: waitSoFar,
          cls: c.class || c.predictedClass || null,
          isRunning: c.pid === runningPid,
        };
      });

    if (isAars) {
      rows.sort((a, b) => b.score - a.score);
    } else {
      rows.sort((a, b) => (b.priority || 0) - (a.priority || 0) || a.pid - b.pid);
    }

    if (rows.length === 0) {
      $('ready-queue-empty').hidden = false;
      tbody.parentElement.hidden = true;
      return;
    }
    $('ready-queue-empty').hidden = true;
    tbody.parentElement.hidden = false;

    for (const r of rows) {
      const tr = document.createElement('tr');
      tr.className = 'rq-row-accent' + (r.isRunning ? ' rq-row-running' : '');
      tr.style.borderLeftColor = processColor(r.pid);
      const cls = (r.cls || 'unknown').toString().toLowerCase().replace('_', '-');
      tr.innerHTML = `
        <td>P${r.pid}${r.isRunning ? ' <span class="text-label">RUNNING</span>' : ''}</td>
        <td>${r.priority !== null ? r.priority : '—'}</td>
        <td>${r.burstRemaining}</td>
        <td>${r.wait}</td>
        <td${isAars ? '' : ' class="hidden-col" style="display:none"'}>${r.score.toFixed(1)}</td>
        <td><span class="class-pill ${cls}">${(r.cls || 'UNKNOWN').toString().toUpperCase()}</span></td>
      `;
      tbody.appendChild(tr);
    }
  }

  function renderWhyPanel(s, data) {
    const decision = lastDecisionAt(data, s.currentTick);
    const empty = $('why-empty');
    const content = $('why-content');
    if (!decision) {
      empty.hidden = false;
      content.hidden = true;
      return;
    }
    empty.hidden = true;
    content.hidden = false;

    const pid = decision.chosen;
    const color = processColor(pid);
    $('why-header').innerHTML = `WHY <span class="pid-color" style="color:${color}">P${pid}</span>?`;

    const list = $('why-reasons');
    list.innerHTML = '';
    for (const tag of decision.reasonTags || []) {
      const h = humanizeReasonTag(tag, decision.candidates);
      const li = document.createElement('li');
      let html = `<span class="why-check">✓</span><span>${h.text}`;
      if (h.delta) {
        html += `<span class="${h.positive ? 'delta-positive' : 'delta-negative'}">${h.delta}</span>`;
      }
      html += '</span>';
      li.innerHTML = html;
      list.appendChild(li);
    }

    const chosenCandidate = (decision.candidates || []).find((c) => c.pid === pid);
    const score = chosenCandidate ? chosenCandidate.score : null;
    $('why-score-value').textContent = score !== null ? score.toFixed(1) : '—';

    // Score breakdown bar: parse any ":+/-N" tagged reasonTags into segments.
    // Requires the scheduler to tag every formula term, not just some —
    // see schema-gap note at top of file.
    const bar = $('why-score-bar');
    bar.innerHTML = '';
    let positives = [];
    let negatives = [];
    for (const tag of decision.reasonTags || []) {
      const m = tag.match(/^([a-z_]+):([+-][\d.]+)$/i);
      if (!m) continue;
      const val = parseFloat(m[2]);
      if (val >= 0) positives.push(val);
      else negatives.push(Math.abs(val));
    }
    const total = positives.reduce((a, b) => a + b, 0) + negatives.reduce((a, b) => a + b, 0) || 1;
    for (const v of positives) {
      const seg = document.createElement('div');
      seg.className = 'seg positive';
      seg.style.width = `${(v / total) * 100}%`;
      bar.appendChild(seg);
    }
    for (const v of negatives) {
      const seg = document.createElement('div');
      seg.className = 'seg negative';
      seg.style.width = `${(v / total) * 100}%`;
      bar.appendChild(seg);
    }
  }

  function renderAgingList(s, data, meta) {
    const decision = lastDecisionAt(data, s.currentTick);
    const ul = $('aging-list');
    ul.innerHTML = '';
    if (!decision) {
      $('aging-empty').hidden = false;
      return;
    }
    const runningSeg = runningSegmentAt(data, s.currentTick);
    const runningPid = runningSeg ? runningSeg.pid : null;

    const entries = [];
    for (const c of decision.candidates || []) {
      if (c.pid === runningPid) continue;
      const m = meta[c.pid];
      if (!m || m.arrivalTime > s.currentTick || m.completionTime <= s.currentTick) continue;
      const ranSoFar = ticksRunUpTo(data, c.pid, s.currentTick);
      const waitSoFar = Math.max(0, s.currentTick - m.arrivalTime - ranSoFar);
      const bonus = estimateAgingBonus(waitSoFar);
      if (bonus > 0) entries.push({ pid: c.pid, waitSoFar, bonus });
    }

    if (entries.length === 0) {
      $('aging-empty').hidden = false;
      return;
    }
    $('aging-empty').hidden = true;

    for (const e of entries) {
      const li = document.createElement('li');
      const wasAbove = agingAboveThreshold.get(e.pid) || false;
      const isAbove = e.bonus >= AGING_WARNING_THRESHOLD;
      let flashClass = '';
      if (isAbove !== wasAbove) {
        flashClass = isAbove ? ' warning-flash' : '';
      }
      agingAboveThreshold.set(e.pid, isAbove);
      li.className = 'is-ready-aging' + flashClass;
      li.innerHTML = `<span>P${e.pid} &nbsp;${e.waitSoFar} ticks waiting</span><span class="aging-bonus-value">→ +${e.bonus.toFixed(1)} aging</span>`;
      ul.appendChild(li);
    }
  }

  function renderPlaybackUI(s, mt) {
    $('tick-readout').textContent = String(s.currentTick);
    $('tick-max').textContent = String(mt);
    const pct = mt > 0 ? (s.currentTick / mt) * 100 : 0;
    $('scrub-fill').style.width = `${pct}%`;
    $('scrub-thumb').style.left = `${pct}%`;
    $('btn-play-pause').textContent = s.isPlaying ? '⏸' : '▶';

    document.querySelectorAll('.speed-btn').forEach((b) => {
      b.classList.toggle('is-active', parseFloat(b.dataset.speed) === s.speed);
    });
  }

  // ---------------------------------------------------------------
  // Playback control flow — ARCHITECTURE.md §5.3
  // ---------------------------------------------------------------

  function play() {
    if (!state.resultData) return;
    state.isPlaying = true;
    const mt = maxTick(state.resultData);
    intervalId = setInterval(() => {
      state.currentTick += 1;
      if (state.currentTick >= mt) {
        state.currentTick = mt;
        pause();
      }
      render(state);
    }, 1000 / (BASE_TICKS_PER_SECOND * state.speed));
    render(state);
  }

  function pause() {
    state.isPlaying = false;
    if (intervalId) clearInterval(intervalId);
    intervalId = null;
    render(state);
  }

  function stepForward() {
    pause();
    const mt = maxTick(state.resultData || { gantt: [], processStats: [] });
    state.currentTick = Math.min(mt, state.currentTick + 1);
    render(state);
  }

  function stepBack() {
    pause();
    state.currentTick = Math.max(0, state.currentTick - 1);
    render(state);
  }

  function resetPlayback() {
    pause();
    state.currentTick = 0;
    render(state);
  }

  function scrubTo(tick) {
    pause();
    state.currentTick = Math.max(0, tick);
    render(state);
  }

  // ---------------------------------------------------------------
  // Loading a result file — file:// safe (input picker, not fetch)
  // ---------------------------------------------------------------

  function loadResultData(json) {
    state.resultData = json;
    state.currentTick = 0;
    state.isPlaying = false;
    lastRunningPid = null;
    agingFlashed = new Set();
    agingAboveThreshold = new Map();
    render(state);
    animateLoadIn('#panel-gantt, #panel-playback, #panel-ready-queue, #panel-why, #panel-aging');
  }

  function handleFile(file) {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const json = JSON.parse(e.target.result);
        loadResultData(json);
      } catch (err) {
        console.error('ChronOS: failed to parse result JSON', err);
        alert('Could not parse that file as a ChronOS result JSON.');
      }
    };
    reader.readAsText(file);
  }

  // ---------------------------------------------------------------
  // Wire up controls
  // ---------------------------------------------------------------

  function init() {
    document.querySelectorAll('.btn').forEach(attachHoverLift);

    $('btn-play-pause').addEventListener('click', () => (state.isPlaying ? pause() : play()));
    $('btn-step-fwd').addEventListener('click', stepForward);
    $('btn-step-back').addEventListener('click', stepBack);
    $('btn-reset').addEventListener('click', resetPlayback);

    document.querySelectorAll('.speed-btn').forEach((b) => {
      b.addEventListener('click', () => {
        state.speed = parseFloat(b.dataset.speed);
        playheadQuickTo = null; // duration is baked in at creation — force a rebuild at the new speed
        if (state.isPlaying) { pause(); play(); } else { render(state); }
      });
    });

    const scrubBar = $('scrub-bar');
    let scrubbing = false;
    function scrubFromEvent(ev) {
      if (!state.resultData) return;
      const rect = scrubBar.getBoundingClientRect();
      const pct = Math.min(1, Math.max(0, (ev.clientX - rect.left) / rect.width));
      const mt = maxTick(state.resultData);
      scrubTo(Math.round(pct * mt));
    }
    scrubBar.addEventListener('mousedown', (ev) => { scrubbing = true; scrubFromEvent(ev); });
    window.addEventListener('mousemove', (ev) => { if (scrubbing) scrubFromEvent(ev); });
    window.addEventListener('mouseup', () => { scrubbing = false; });

    const fileInput = $('file-input');
    fileInput.addEventListener('change', (ev) => {
      if (ev.target.files && ev.target.files[0]) handleFile(ev.target.files[0]);
    });
    $('btn-run').addEventListener('click', () => fileInput.click());

    // Keyboard: space = play/pause, arrows = step, when not focused on a control
    window.addEventListener('keydown', (ev) => {
      if (['INPUT', 'SELECT', 'BUTTON'].includes(document.activeElement.tagName)) return;
      if (ev.code === 'Space') { ev.preventDefault(); state.isPlaying ? pause() : play(); }
      if (ev.code === 'ArrowRight') stepForward();
      if (ev.code === 'ArrowLeft') stepBack();
    });

    render(state);
    initIntro(() => animateLoadIn('#topbar, #empty-state, .footer'));
  }

  document.addEventListener('DOMContentLoaded', init);
})();
