/**
 * tracker.js
 *
 * Raw event tracker — records every user interaction as individual events
 * and flushes them to the backend every FLUSH_INTERVAL ms.
 *
 * Event types recorded:
 *   pointer-move   { type, x, y, ts, pointerType, element }
 *   pointer-down   { type, x, y, ts, pointerType, element }
 *   pointer-up     { type, x, y, ts, pointerType, element }
 *   pointer-over   { type, element, x, y, ts, pointerType }
 *   pointer-out    { type, element, x, y, ts, pointerType, duration }
 *   key-down       { type, key, x, y, ts, element }  // Enter/Space on activatable elements
 *   highlight      { type, x, y, ts, text, charCount }
 *   scroll         { type, x, y, ts, scrollX, scrollY, direction }
 *   slider-change  { type, element, x, y, ts, value, phase }  // phase: 'drag' | 'release'
 *
 * Usage:
 *   tracker.start(userId)   — begin tracking
 *   tracker.stop()          — flush remaining data and detach listeners
 *   tracker.getBinaryBlob() — encode fullHistory as SBEH binary (call before stop)
 */

import axios from 'axios';
import { encode as msgpackEncode } from '@msgpack/msgpack';

const FLUSH_INTERVAL = 100;  // ms — periodic flush cadence
const MIN_DISTANCE   = 1;    // px — minimum movement to record a pointer-move sample

// ── LocalStorage persistence ──────────────────────────────────────────────────

function historyKey(uid) {
  return `survey_behavior_history_${uid}`;
}

function loadPersistedHistory(uid) {
  try {
    const raw = localStorage.getItem(historyKey(uid));
    return raw ? JSON.parse(raw) : [];
  } catch (_) {
    return [];
  }
}

function savePersistedHistory(uid, history) {
  try {
    localStorage.setItem(historyKey(uid), JSON.stringify(history));
  } catch (_) { /* quota exceeded — silently skip */ }
}

// ── Module-level state (reset on each start()) ───────────────────────────────

let userId        = null;
let lastRecordedX = null;
let lastRecordedY = null;
let lastScrollY   = window.scrollY;
let hoverMap      = {};

let rawQueue    = [];   // events pending flush to DB
let fullHistory = [];   // all events (for binary export), persisted across refreshes
let flushTimer  = null;
let paused      = false;

// ── Internal helpers ──────────────────────────────────────────────────────────

function pushEvent(evt) {
  rawQueue.push(evt);
  fullHistory.push(evt);
  if (tracker.onEvent) tracker.onEvent(evt);
}

async function flush() {
  if (paused) return;
  if (!userId || rawQueue.length === 0) return;

  const batch = rawQueue.splice(0);
  try {
    await axios.post(
      `/api/behavior/${encodeURIComponent(userId)}/events`,
      { events: batch }
    );
    savePersistedHistory(userId, fullHistory);
  } catch (err) {
    console.warn('[tracker] flush failed, re-queuing:', err.message);
    rawQueue.unshift(...batch);
  }
}

function throttle(fn, delay) {
  let last = 0;
  return function (...args) {
    const t = Date.now();
    if (t - last >= delay) { last = t; fn.apply(this, args); }
  };
}

// ── DOM event handlers ────────────────────────────────────────────────────────

const onPointerMove = (e) => {
  const cx = Math.round(e.clientX);
  const cy = Math.round(e.clientY);

  if (lastRecordedX !== null) {
    const dx = cx - lastRecordedX;
    const dy = cy - lastRecordedY;
    if (Math.sqrt(dx * dx + dy * dy) < MIN_DISTANCE) return;
  }
  lastRecordedX = cx;
  lastRecordedY = cy;

  const element = e.target.closest('[data-track]')?.dataset.track ?? null;
  pushEvent({ type: 'pointer-move', x: cx, y: cy, ts: Date.now(), pointerType: e.pointerType, element });
};

function onPointerDown(e) {
  const element = e.target.closest('[data-track]')?.dataset.track ?? null;
  pushEvent({ type: 'pointer-down', x: Math.round(e.clientX), y: Math.round(e.clientY), ts: Date.now(), pointerType: e.pointerType, element });
}

function onPointerUp(e) {
  const element = e.target.closest('[data-track]')?.dataset.track ?? null;
  pushEvent({ type: 'pointer-up', x: Math.round(e.clientX), y: Math.round(e.clientY), ts: Date.now(), pointerType: e.pointerType, element });
}

const ACTIVATABLE_SELECTOR =
  'button, a[href], [role="button"], [role="link"], ' +
  'input[type="submit"], input[type="button"], input[type="reset"], ' +
  'input[type="checkbox"], input[type="radio"]';

function onKeyDown(e) {
  if (e.key !== 'Enter' && e.key !== ' ') return;
  if (e.repeat) return;
  const el = e.target;
  if (!el.matches?.(ACTIVATABLE_SELECTOR)) return;
  const rect    = el.getBoundingClientRect();
  const element = el.closest('[data-track]')?.dataset.track ?? null;
  pushEvent({
    type:    'key-down',
    key:     e.key === ' ' ? 'Space' : e.key,
    x:       Math.round(rect.left + rect.width / 2),
    y:       Math.round(rect.top + rect.height / 2),
    ts:      Date.now(),
    element,
  });
}

function onSelectionChange() {
  const sel = window.getSelection();
  if (!sel || sel.isCollapsed) return;
  const text = sel.toString().trim();
  if (!text) return;

  const range = sel.getRangeAt(0);
  const rect  = range.getBoundingClientRect();
  pushEvent({
    type:      'highlight',
    x:         Math.round(rect.left),
    y:         Math.round(rect.top),
    ts:        Date.now(),
    text,
    charCount: text.length,
  });
}

function onDelegatedPointerOver(e) {
  const el = e.target.closest('[data-track]');
  if (!el) return;
  if (e.relatedTarget && el.contains(e.relatedTarget)) return;
  const key = el.dataset.track;
  hoverMap[key] = { startTime: Date.now(), startX: Math.round(e.clientX), startY: Math.round(e.clientY) };
  pushEvent({ type: 'pointer-over', element: key, x: Math.round(e.clientX), y: Math.round(e.clientY), ts: Date.now(), pointerType: e.pointerType });
}

function onDelegatedPointerOut(e) {
  const el = e.target.closest('[data-track]');
  if (!el) return;
  if (e.relatedTarget && el.contains(e.relatedTarget)) return;
  const key = el.dataset.track;
  if (!hoverMap[key]) return;
  const { startTime } = hoverMap[key];
  delete hoverMap[key];
  const now = Date.now();
  pushEvent({ type: 'pointer-out', element: key, x: Math.round(e.clientX), y: Math.round(e.clientY), ts: now, pointerType: e.pointerType, duration: now - startTime });
}

const onScroll = throttle(() => {
  const currentY  = window.scrollY;
  const direction = currentY > lastScrollY ? 'down' : 'up';
  lastScrollY = currentY;

  pushEvent({
    type:      'scroll',
    x:         lastRecordedX ?? 0,
    y:         lastRecordedY ?? 0,
    ts:        Date.now(),
    scrollX:   window.scrollX,
    scrollY:   currentY,
    direction,
  });
}, FLUSH_INTERVAL);

function onVisibilityChange() {
  if (document.visibilityState === 'hidden') {
    paused = true;
  } else {
    paused      = false;
    lastScrollY = window.scrollY;
    lastRecordedX = null;
    lastRecordedY = null;
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

const tracker = {
  start(uid) {
    if (!uid) { console.warn('[tracker] No user ID — tracking disabled.'); return; }
    if (userId) {
      console.warn('[tracker] Already running — call stop() first.');
      return;
    }
    userId        = uid;
    rawQueue      = [];
    fullHistory   = loadPersistedHistory(uid);
    lastRecordedX = null;
    lastRecordedY = null;
    lastScrollY   = window.scrollY;
    hoverMap      = {};
    paused        = document.visibilityState === 'hidden';

    document.addEventListener('pointermove',      onPointerMove);
    document.addEventListener('pointerdown',      onPointerDown);
    document.addEventListener('pointerup',        onPointerUp);
    document.addEventListener('keydown',          onKeyDown);
    document.addEventListener('selectionchange',  onSelectionChange);
    document.addEventListener('scroll',           onScroll, { passive: true });
    document.addEventListener('visibilitychange', onVisibilityChange);
    document.addEventListener('pointerover',      onDelegatedPointerOver);
    document.addEventListener('pointerout',       onDelegatedPointerOut);

    clearInterval(flushTimer);
    flushTimer = setInterval(flush, FLUSH_INTERVAL);
  },

  async stop() {
    document.removeEventListener('pointermove',      onPointerMove);
    document.removeEventListener('pointerdown',      onPointerDown);
    document.removeEventListener('pointerup',        onPointerUp);
    document.removeEventListener('keydown',          onKeyDown);
    document.removeEventListener('selectionchange',  onSelectionChange);
    document.removeEventListener('scroll',           onScroll);
    document.removeEventListener('visibilitychange', onVisibilityChange);
    document.removeEventListener('pointerover',      onDelegatedPointerOver);
    document.removeEventListener('pointerout',       onDelegatedPointerOut);

    clearInterval(flushTimer);
    await flush();
    userId = null;
  },

  /**
   * Record a slider interaction. Called directly from SliderBar.vue.
   */
  recordSlider(value, selector = '.slider-bar', x = null, y = null, phase = 'drag') {
    pushEvent({
      type:    'slider-change',
      element: selector,
      x:       x !== null ? Math.round(x) : 0,
      y:       y !== null ? Math.round(y) : 0,
      ts:      Date.now(),
      value,
      phase,
    });
  },

  getLastPosition() {
    return { x: lastRecordedX, y: lastRecordedY };
  },

  clearPersistedHistory() {
    if (userId) localStorage.removeItem(historyKey(userId));
    fullHistory = [];
  },

  /**
   * Encode the full session event history as a binary blob for S3 upload.
   *
   * Binary format:
   *   Bytes 0–3  : Magic "SBEH"  (0x53 0x42 0x45 0x48)
   *   Bytes 4–5  : uid length    (uint16, big-endian)
   *   Bytes 6–N  : uid           (UTF-8 string)
   *   Bytes N+1… : msgpack-encoded Array of raw event objects
   *
   * Call this before tracker.stop() (while userId is still set).
   */
  getBinaryBlob() {
    const uid      = userId || '';
    const uidBytes = new TextEncoder().encode(uid);
    const payload  = msgpackEncode(fullHistory);

    const result = new Uint8Array(4 + 2 + uidBytes.length + payload.length);
    const view   = new DataView(result.buffer);

    result[0] = 0x53; result[1] = 0x42;
    result[2] = 0x45; result[3] = 0x48;

    view.setUint16(4, uidBytes.length, false);
    result.set(uidBytes, 6);
    result.set(payload, 6 + uidBytes.length);

    return result.buffer;
  },
};

export default tracker;
