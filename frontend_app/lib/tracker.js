/**
 * tracker.js
 *
 * Trajectory-based user behaviour tracker.
 *
 * Raw DOM events are grouped into trajectory objects before being sent to the
 * backend.  Each trajectory has a short type code and a compact events array:
 *
 *   MM  Mouse Movement   [[x, y, "mousemove", ts_ms], ...]
 *   PC  Point & Click    [[x, y, "mousedown", ts], [x, y, "mouseup", ts], [x, y, "click", ts]]
 *   HL  Highlight        [[x, y, "highlight", ts, text, char_count]]
 *   HV  Hover            [[x_enter, y_enter, "mouseenter", ts], [x_exit, y_exit, "mouseleave", ts, duration_ms]]
 *   SC  Scroll           [[x, y, "scroll", ts, scroll_x, scroll_y, direction], ...]
 *   SL  Slider           [[x, y, "slider", ts, value]]
 *
 * Trajectories are flushed to the backend every FLUSH_INTERVAL ms.
 * A full in-memory history is kept so that tracker.getBinaryBlob() can produce
 * a msgpack binary for S3 upload on submit.
 *
 * Usage:
 *   tracker.start(userId)   — begin tracking
 *   tracker.stop()          — flush remaining data and detach listeners
 *   tracker.getBinaryBlob() — encode fullHistory as SBEH binary (call before stop)
 */

import axios from 'axios';
import { encode as msgpackEncode } from '@msgpack/msgpack';

const FLUSH_INTERVAL  = 100;   // ms — periodic flush cadence
const MAX_BUFFER      = 500;   // flush MM/SC early when buffer hits this size
const MOTION_THROTTLE = 16;    // ms — ~60 fps cap for mousemove
const MIN_DISTANCE    = 4;     // px — minimum movement to record a mousemove sample

// ── Module-level state (reset on each start()) ───────────────────────────────

let userId        = null;
let lastRecordedX = null;
let lastRecordedY = null;
let lastScrollY   = window.scrollY;
let hoverMap      = {};

let mmBuffer        = [];               // accumulating mousemove points
let scBuffer        = [];               // accumulating scroll points
let pcState         = { down: null, up: null };  // mousedown/mouseup waiting for click
let trajectoryQueue = [];               // completed trajectories pending flush to DB
let fullHistory     = [];               // all completed trajectories (for binary export)
let flushTimer      = null;

// ── Internal helpers ──────────────────────────────────────────────────────────

function pushTrajectory(type, events) {
  const traj = { type, events };
  trajectoryQueue.push(traj);
  fullHistory.push(traj);
}

function drainMM() {
  if (mmBuffer.length === 0) return;
  pushTrajectory('MM', mmBuffer.splice(0));
}

function drainSC() {
  if (scBuffer.length === 0) return;
  pushTrajectory('SC', scBuffer.splice(0));
}

async function flush() {
  drainMM();
  drainSC();
  if (!userId || trajectoryQueue.length === 0) return;

  const batch = trajectoryQueue.splice(0);
  try {
    await axios.post(
      `/api/behavior/${encodeURIComponent(userId)}/events`,
      { trajectories: batch }
    );
  } catch (err) {
    console.warn('[tracker] flush failed, re-queuing:', err.message);
    trajectoryQueue.unshift(...batch);
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

const onMouseMove = throttle((e) => {
  const cx = Math.round(e.clientX);
  const cy = Math.round(e.clientY);

  if (lastRecordedX !== null) {
    const dx = cx - lastRecordedX;
    const dy = cy - lastRecordedY;
    if (Math.sqrt(dx * dx + dy * dy) < MIN_DISTANCE) return;
  }
  lastRecordedX = cx;
  lastRecordedY = cy;

  mmBuffer.push([cx, cy, 'mousemove', Date.now()]);
  if (mmBuffer.length >= MAX_BUFFER) drainMM();
}, MOTION_THROTTLE);

function onMouseDown(e) {
  pcState.down = [Math.round(e.clientX), Math.round(e.clientY), 'mousedown', Date.now()];
  pcState.up   = null;
}

function onMouseUp(e) {
  if (pcState.down) {
    pcState.up = [Math.round(e.clientX), Math.round(e.clientY), 'mouseup', Date.now()];
  }
}

function onClick(e) {
  const clickEvt = [Math.round(e.clientX), Math.round(e.clientY), 'click', Date.now()];
  const events = [];
  if (pcState.down) events.push(pcState.down);
  if (pcState.up)   events.push(pcState.up);
  events.push(clickEvt);
  pushTrajectory('PC', events);
  pcState.down = null;
  pcState.up   = null;
}

function onSelectionChange() {
  const sel = window.getSelection();
  if (!sel || sel.isCollapsed) return;
  const text = sel.toString().trim();
  if (!text) return;

  const range = sel.getRangeAt(0);
  const rect  = range.getBoundingClientRect();
  pushTrajectory('HL', [[
    Math.round(rect.left),
    Math.round(rect.top),
    'highlight',
    Date.now(),
    text,
    text.length,
  ]]);
}

function onMouseEnter(e) {
  const key = e.currentTarget.dataset.track || e.currentTarget.tagName;
  hoverMap[key] = {
    startTime: Date.now(),
    startX:    Math.round(e.clientX),
    startY:    Math.round(e.clientY),
  };
}

function onMouseLeave(e) {
  const key = e.currentTarget.dataset.track || e.currentTarget.tagName;
  if (!hoverMap[key]) return;
  const { startTime, startX, startY } = hoverMap[key];
  delete hoverMap[key];

  pushTrajectory('HV', [
    [startX, startY, 'mouseenter', startTime],
    [Math.round(e.clientX), Math.round(e.clientY), 'mouseleave', Date.now(), Date.now() - startTime],
  ]);
}

const onScroll = throttle(() => {
  const currentY  = window.scrollY;
  const direction = currentY > lastScrollY ? 'down' : 'up';
  lastScrollY = currentY;

  scBuffer.push([
    lastRecordedX ?? 0,
    lastRecordedY ?? 0,
    'scroll',
    Date.now(),
    window.scrollX,
    currentY,
    direction,
  ]);
  if (scBuffer.length >= MAX_BUFFER) drainSC();
}, FLUSH_INTERVAL);

// ── Public API ────────────────────────────────────────────────────────────────

const tracker = {
  start(uid) {
    if (!uid) { console.warn('[tracker] No user ID — tracking disabled.'); return; }
    userId          = uid;
    mmBuffer        = [];
    scBuffer        = [];
    pcState         = { down: null, up: null };
    trajectoryQueue = [];
    fullHistory     = [];
    lastRecordedX   = null;
    lastRecordedY   = null;
    lastScrollY     = window.scrollY;
    hoverMap        = {};

    document.addEventListener('mousemove',       onMouseMove);
    document.addEventListener('mousedown',       onMouseDown);
    document.addEventListener('mouseup',         onMouseUp);
    document.addEventListener('click',           onClick);
    document.addEventListener('selectionchange', onSelectionChange);
    document.addEventListener('scroll',          onScroll, { passive: true });

    document.querySelectorAll('[data-track]').forEach(el => {
      el.addEventListener('mouseenter', onMouseEnter);
      el.addEventListener('mouseleave', onMouseLeave);
    });

    flushTimer = setInterval(flush, FLUSH_INTERVAL);
  },

  async stop() {
    document.removeEventListener('mousemove',       onMouseMove);
    document.removeEventListener('mousedown',       onMouseDown);
    document.removeEventListener('mouseup',         onMouseUp);
    document.removeEventListener('click',           onClick);
    document.removeEventListener('selectionchange', onSelectionChange);
    document.removeEventListener('scroll',          onScroll);

    document.querySelectorAll('[data-track]').forEach(el => {
      el.removeEventListener('mouseenter', onMouseEnter);
      el.removeEventListener('mouseleave', onMouseLeave);
    });

    clearInterval(flushTimer);
    await flush();
    userId = null;
  },

  /**
   * Record a slider interaction. Called directly from SliderBar.vue.
   * Also clears any dangling PC state (slider mousedown does not produce a click).
   */
  recordSlider(value, selector = '.slider-bar', x = null, y = null) {
    pcState.down = null;
    pcState.up   = null;

    pushTrajectory('SL', [[
      x !== null ? Math.round(x) : 0,
      y !== null ? Math.round(y) : 0,
      'slider',
      Date.now(),
      value,
    ]]);
  },

  /**
   * Return the last known mouse position.
   * Used by SliderBar.vue since InputEvent/change have no clientX/Y.
   */
  getLastPosition() {
    return { x: lastRecordedX, y: lastRecordedY };
  },

  /**
   * Encode the full session trajectory history as a binary blob for S3 upload.
   *
   * Binary format:
   *   Bytes 0–3  : Magic "SBEH"  (0x53 0x42 0x45 0x48)
   *   Bytes 4–5  : uid length    (uint16, big-endian)
   *   Bytes 6–N  : uid           (UTF-8 string)
   *   Bytes N+1… : msgpack-encoded Array of trajectory objects
   *
   * Call this before tracker.stop() (while userId is still set).
   */
  getBinaryBlob() {
    // Drain any in-progress streaming buffers into fullHistory (without sending to DB)
    if (mmBuffer.length > 0) fullHistory.push({ type: 'MM', events: mmBuffer.slice() });
    if (scBuffer.length > 0) fullHistory.push({ type: 'SC', events: scBuffer.slice() });

    const uid      = userId || '';
    const uidBytes = new TextEncoder().encode(uid);
    const payload  = msgpackEncode(fullHistory);   // Uint8Array

    const result   = new Uint8Array(4 + 2 + uidBytes.length + payload.length);
    const view     = new DataView(result.buffer);

    // Magic "SBEH"
    result[0] = 0x53; result[1] = 0x42;
    result[2] = 0x45; result[3] = 0x48;

    // uid length (uint16 big-endian) + uid bytes
    view.setUint16(4, uidBytes.length, false);
    result.set(uidBytes, 6);

    // msgpack payload
    result.set(payload, 6 + uidBytes.length);

    return result.buffer;
  },
};

export default tracker;
