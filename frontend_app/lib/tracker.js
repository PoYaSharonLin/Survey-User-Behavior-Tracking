/**
 * tracker.js
 *
 * Raw event tracker — records every user interaction as individual events
 * accumulated in memory and exported as a binary blob at submit time.
 *
 * Event types recorded:
 *   pointer-move      { type, x, y, ts, pointerType, element }
 *   pointer-down      { type, x, y, ts, pointerType, element }
 *   pointer-up        { type, x, y, ts, pointerType, element }
 *   pointer-over      { type, element, x, y, ts, pointerType }
 *   pointer-out       { type, element, x, y, ts, pointerType, duration }
 *   key-down          { type, key, code, ctrlKey, shiftKey, altKey, metaKey, x, y, ts, element }
 *   key-up            { type, key, code, ctrlKey, shiftKey, altKey, metaKey, x, y, ts, element }
 *   highlight         { type, x, y, ts, text, charCount }
 *   scroll            { type, x, y, ts, scrollX, scrollY, direction }
 *   slider-change     { type, element, x, y, ts, value, phase }  // phase: 'drag' | 'release'
 *   focus             { type, x, y, ts }  // window-level
 *   blur              { type, x, y, ts }  // window-level
 *   visibility-change { type, x, y, ts, visibilityState }
 *   page-show         { type, x, y, ts, persisted }
 *   page-hide         { type, x, y, ts, persisted }
 *   viewport          { type, ts, innerWidth, innerHeight, devicePixelRatio,
 *                       scrollWidth, scrollHeight, screenWidth, screenHeight, userAgent }
 *   element-rect      { type, ts, element, left, right, top, bottom, width, height,
 *                       thumbWidth?, thumbHeight? }   // page-coords (scrollX/Y added in)
 *
 * Usage:
 *   tracker.start(userId)        — begin tracking
 *   tracker.stop()               — detach listeners; call getBinaryBlob() before this
 *   tracker.recordMetadata(obj)  — push a metadata event (e.g. viewport, element-rect)
 *   tracker.getBinaryBlob()      — encode fullHistory as binary blob (call before stop)
 */

import { encode as msgpackEncode } from '@msgpack/msgpack';

const MIN_DISTANCE    = 1;    // px — minimum movement to record a pointer-move sample
const PERSIST_INTERVAL = 100; // ms — localStorage save cadence

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

let fullHistory  = [];   // all events (for binary export), persisted across refreshes
let persistTimer = null;
let paused       = false;

// ── Internal helpers ──────────────────────────────────────────────────────────

function pushEvent(evt) {
  fullHistory.push(evt);
  if (tracker.onEvent) tracker.onEvent(evt);
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
  const px = Math.round(e.pageX);
  const py = Math.round(e.pageY);

  if (lastRecordedX !== null) {
    const dx = px - lastRecordedX;
    const dy = py - lastRecordedY;
    if (Math.sqrt(dx * dx + dy * dy) < MIN_DISTANCE) return;
  }
  lastRecordedX = px;
  lastRecordedY = py;

  const element = e.target.closest('[data-track]')?.dataset.track ?? null;
  pushEvent({ type: 'pointer-move', x: px, y: py, ts: Date.now(), pointerType: e.pointerType, element });
};

function onPointerDown(e) {
  const element = e.target.closest('[data-track]')?.dataset.track ?? null;
  pushEvent({ type: 'pointer-down', x: Math.round(e.pageX), y: Math.round(e.pageY), ts: Date.now(), pointerType: e.pointerType, element });
}

function onPointerUp(e) {
  const element = e.target.closest('[data-track]')?.dataset.track ?? null;
  pushEvent({ type: 'pointer-up', x: Math.round(e.pageX), y: Math.round(e.pageY), ts: Date.now(), pointerType: e.pointerType, element });
}

function focusedElementCenter() {
  const el = document.activeElement;
  if (!el || el === document.body || !el.getBoundingClientRect) {
    return { x: null, y: null, element: null };
  }
  const rect = el.getBoundingClientRect();
  return {
    x:       Math.round(rect.left + window.scrollX + rect.width / 2),
    y:       Math.round(rect.top + window.scrollY + rect.height / 2),
    element: el.closest?.('[data-track]')?.dataset.track ?? null,
  };
}

function onKeyDown(e) {
  if (e.repeat) return;
  const { x, y, element } = focusedElementCenter();
  pushEvent({
    type:     'key-down',
    key:      e.key === ' ' ? 'Space' : e.key,
    code:     e.code,
    ctrlKey:  e.ctrlKey,
    shiftKey: e.shiftKey,
    altKey:   e.altKey,
    metaKey:  e.metaKey,
    x,
    y,
    ts:       Date.now(),
    element,
  });
}

function onKeyUp(e) {
  if (e.repeat) return;
  const { x, y, element } = focusedElementCenter();
  pushEvent({
    type:     'key-up',
    key:      e.key === ' ' ? 'Space' : e.key,
    code:     e.code,
    ctrlKey:  e.ctrlKey,
    shiftKey: e.shiftKey,
    altKey:   e.altKey,
    metaKey:  e.metaKey,
    x,
    y,
    ts:       Date.now(),
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
    x:         Math.round(rect.left + window.scrollX),
    y:         Math.round(rect.top + window.scrollY),
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
  hoverMap[key] = { startTime: Date.now(), startX: Math.round(e.pageX), startY: Math.round(e.pageY) };
  pushEvent({ type: 'pointer-over', element: key, x: Math.round(e.pageX), y: Math.round(e.pageY), ts: Date.now(), pointerType: e.pointerType });
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
  pushEvent({ type: 'pointer-out', element: key, x: Math.round(e.pageX), y: Math.round(e.pageY), ts: now, pointerType: e.pointerType, duration: now - startTime });
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
}, 100);

function onVisibilityChange() {
  const visibilityState = document.visibilityState;
  pushEvent({
    type: 'visibility-change',
    x:    null,
    y:    null,
    ts:   Date.now(),
    visibilityState,
  });
  if (visibilityState === 'hidden') {
    paused = true;
  } else {
    paused        = false;
    lastScrollY   = window.scrollY;
    lastRecordedX = null;
    lastRecordedY = null;
  }
}

function onWindowFocus() {
  pushEvent({ type: 'focus', x: null, y: null, ts: Date.now() });
}

function onWindowBlur() {
  pushEvent({ type: 'blur', x: null, y: null, ts: Date.now() });
}

function onPageShow(e) {
  pushEvent({ type: 'page-show', x: null, y: null, ts: Date.now(), persisted: e.persisted });
}

function onPageHide(e) {
  pushEvent({ type: 'page-hide', x: null, y: null, ts: Date.now(), persisted: e.persisted });
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
    document.addEventListener('keyup',            onKeyUp);
    document.addEventListener('selectionchange',  onSelectionChange);
    document.addEventListener('scroll',           onScroll, { passive: true });
    document.addEventListener('visibilitychange', onVisibilityChange);
    document.addEventListener('pointerover',      onDelegatedPointerOver);
    document.addEventListener('pointerout',       onDelegatedPointerOut);
    window.addEventListener('focus',              onWindowFocus);
    window.addEventListener('blur',               onWindowBlur);
    window.addEventListener('pageshow',           onPageShow);
    window.addEventListener('pagehide',           onPageHide);

    clearInterval(persistTimer);
    persistTimer = setInterval(() => savePersistedHistory(userId, fullHistory), PERSIST_INTERVAL);
  },

  stop() {
    document.removeEventListener('pointermove',      onPointerMove);
    document.removeEventListener('pointerdown',      onPointerDown);
    document.removeEventListener('pointerup',        onPointerUp);
    document.removeEventListener('keydown',          onKeyDown);
    document.removeEventListener('keyup',            onKeyUp);
    document.removeEventListener('selectionchange',  onSelectionChange);
    document.removeEventListener('scroll',           onScroll);
    document.removeEventListener('visibilitychange', onVisibilityChange);
    document.removeEventListener('pointerover',      onDelegatedPointerOver);
    document.removeEventListener('pointerout',       onDelegatedPointerOut);
    window.removeEventListener('focus',              onWindowFocus);
    window.removeEventListener('blur',               onWindowBlur);
    window.removeEventListener('pageshow',           onPageShow);
    window.removeEventListener('pagehide',           onPageHide);

    clearInterval(persistTimer);
    if (userId) savePersistedHistory(userId, fullHistory);
    userId = null;
  },

  /**
   * Record a metadata event (viewport, element-rect, etc.). Called from page
   * components after layout-affecting events (mount, resize). Caller supplies
   * `type` and any payload fields; `ts` is added automatically.
   */
  recordMetadata(payload) {
    pushEvent({ ...payload, ts: Date.now() });
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
   *   Bytes 0–1  : uid length    (uint16, big-endian)
   *   Bytes 2–N  : uid           (UTF-8 string)
   *   Bytes N+1… : msgpack-encoded Array of raw event objects
   *
   * Call this before tracker.stop() (while userId is still set).
   */
  getBinaryBlob() {
    const uid      = userId || '';
    const uidBytes = new TextEncoder().encode(uid);
    const payload  = msgpackEncode(fullHistory);

    const result = new Uint8Array(2 + uidBytes.length + payload.length);
    const view   = new DataView(result.buffer);

    view.setUint16(0, uidBytes.length, false);
    result.set(uidBytes, 2);
    result.set(payload, 2 + uidBytes.length);

    return result.buffer;
  },
};

export default tracker;
