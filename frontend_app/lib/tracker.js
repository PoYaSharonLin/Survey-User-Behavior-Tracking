/**
 * tracker.js
 *
 * Fine-grained user behaviour tracker.
 *
 * Captures the following event types:
 *   - mousemove  : pixel-level position, throttled at 300 ms, batched
 *   - click      : click target selector + coordinates
 *   - highlight  : text selection via getSelection()
 *   - hover      : mouseenter/mouseleave on [data-track] elements (records duration)
 *   - scroll     : scroll position + direction (throttled at 300 ms)
 *   - slider     : captured when SliderBar emits a change
 *
 * Call tracker.start(userId) to begin and tracker.stop() to end.
 * All events are flushed every FLUSH_INTERVAL ms or on stop().
 */

import axios from 'axios';

const FLUSH_INTERVAL = 300;   // ms — matches 300ms throttle requirement
const MAX_BATCH      = 200;   // safeguard: don't queue more than this before flushing

let userId       = null;
let queue        = [];
let flushTimer   = null;
let hoverMap     = {};        // element -> { startTime }
let lastScrollY  = window.scrollY;

// ── Helpers ──────────────────────────────────────────────────────────────────

function cssSelector(el) {
  if (!el || el === document.body) return 'body';
  if (el.id) return `#${el.id}`;
  const parent = cssSelector(el.parentElement);
  const tag    = el.tagName.toLowerCase();
  const cls    = [...el.classList].map(c => `.${c}`).join('');
  return `${parent} > ${tag}${cls}`;
}

function enqueue(event) {
  queue.push({ ...event, timestamp: new Date().toISOString() });
  if (queue.length >= MAX_BATCH) flush();
}

async function flush() {
  if (!userId || queue.length === 0) return;
  const batch = queue.splice(0, queue.length);   // drain queue atomically
  try {
    await axios.post(`/api/behavior/${encodeURIComponent(userId)}/events`, { events: batch });
  } catch (err) {
    console.warn('[tracker] flush failed, re-queuing batch:', err.message);
    queue.unshift(...batch);   // put back on failure
  }
}

// ── Throttle helper ───────────────────────────────────────────────────────────

function throttle(fn, delay) {
  let last = 0;
  return function (...args) {
    const now = Date.now();
    if (now - last >= delay) { last = now; fn.apply(this, args); }
  };
}

// ── Event handlers ────────────────────────────────────────────────────────────

const onMouseMove = throttle((e) => {
  enqueue({
    event_type:       'mousemove',
    x:                Math.round(e.clientX),
    y:                Math.round(e.clientY),
    element_selector: cssSelector(e.target),
  });
}, FLUSH_INTERVAL);

function onClick(e) {
  enqueue({
    event_type:       'click',
    x:                Math.round(e.clientX),
    y:                Math.round(e.clientY),
    element_selector: cssSelector(e.target),
  });
}

function onSelectionChange() {
  const sel = window.getSelection();
  if (!sel || sel.isCollapsed) return;
  const text = sel.toString().trim();
  if (!text) return;

  const range     = sel.getRangeAt(0);
  const rect      = range.getBoundingClientRect();
  enqueue({
    event_type:       'highlight',
    x:                Math.round(rect.left),
    y:                Math.round(rect.top),
    text_content:     text,
    element_selector: cssSelector(range.startContainer.parentElement),
    extra:            JSON.stringify({
      start_offset: range.startOffset,
      end_offset:   range.endOffset,
      char_count:   text.length,
    }),
  });
}

function onMouseEnter(e) {
  const el = e.currentTarget;
  hoverMap[cssSelector(el)] = { startTime: Date.now() };
}

function onMouseLeave(e) {
  const el  = e.currentTarget;
  const key = cssSelector(el);
  if (!hoverMap[key]) return;
  const duration = Date.now() - hoverMap[key].startTime;
  delete hoverMap[key];
  enqueue({
    event_type:       'hover',
    element_selector: key,
    x:                Math.round(e.clientX),
    y:                Math.round(e.clientY),
    extra:            JSON.stringify({ duration_ms: duration }),
  });
}

const onScroll = throttle(() => {
  const currentY  = window.scrollY;
  const direction = currentY > lastScrollY ? 'down' : 'up';
  lastScrollY     = currentY;
  enqueue({
    event_type: 'scroll',
    extra:      JSON.stringify({
      scroll_x:  window.scrollX,
      scroll_y:  currentY,
      direction,
    }),
  });
}, FLUSH_INTERVAL);

// ── Public API ─────────────────────────────────────────────────────────────────

const tracker = {
  /**
   * Start tracking.
   * @param {string} uid - The survey user ID from session.getUserId()
   */
  start(uid) {
    if (!uid) { console.warn('[tracker] No user ID provided, tracking disabled.'); return; }
    userId = uid;
    queue  = [];

    document.addEventListener('mousemove',       onMouseMove);
    document.addEventListener('click',           onClick);
    document.addEventListener('selectionchange', onSelectionChange);
    document.addEventListener('scroll',          onScroll, { passive: true });

    // Attach hover listeners to all [data-track] elements
    document.querySelectorAll('[data-track]').forEach(el => {
      el.addEventListener('mouseenter', onMouseEnter);
      el.addEventListener('mouseleave', onMouseLeave);
    });

    // Start periodic flush
    flushTimer = setInterval(flush, FLUSH_INTERVAL);
  },

  /**
   * Stop tracking and flush remaining events.
   */
  async stop() {
    document.removeEventListener('mousemove',       onMouseMove);
    document.removeEventListener('click',           onClick);
    document.removeEventListener('selectionchange', onSelectionChange);
    document.removeEventListener('scroll',          onScroll);

    document.querySelectorAll('[data-track]').forEach(el => {
      el.removeEventListener('mouseenter', onMouseEnter);
      el.removeEventListener('mouseleave', onMouseLeave);
    });

    clearInterval(flushTimer);
    await flush();   // drain remaining queue
    userId = null;
  },

  /**
   * Record a slider change event. Called directly from SliderBar.vue.
   * @param {number|string} value - Current slider value
   * @param {string}        selector - Optional CSS selector of the slider element
   */
  recordSlider(value, selector = '.slider-bar') {
    enqueue({
      event_type:       'slider',
      element_selector: selector,
      extra:            JSON.stringify({ value }),
    });
  },
};

export default tracker;
