<template>
  <div class="debug-overlay" v-if="visible">
    <div class="debug-header">
      <span>Live Events ({{ lines.length }})</span>
      <button @click="lines = []">Clear</button>
      <button @click="visible = false">✕</button>
    </div>
    <textarea ref="box" class="debug-box" readonly :value="lines.join('\n')" />
  </div>
</template>

<script>
import tracker from '@/lib/tracker';

const MAX_LINES = 200;

export default {
  name: 'DebugOverlay',

  data() {
    return { lines: [], visible: true };
  },

  mounted() {
    tracker.onEvent = (evt) => {
      const elem   = evt.element ? `elem=${evt.element}` : '           ';
      const extras = Object.entries(evt)
        .filter(([k]) => !['type', 'x', 'y', 'ts', 'element'].includes(k))
        .map(([k, v]) => `${k}=${typeof v === 'string' ? v.slice(0, 30) : v}`)
        .join(' ');

      const line = `[${evt.type.padEnd(11)}] x=${String(evt.x ?? '').padStart(4)} y=${String(evt.y ?? '').padStart(4)}  ${elem}  ${extras}`;
      this.lines.push(line);
      if (this.lines.length > MAX_LINES) this.lines.shift();

      this.$nextTick(() => {
        const box = this.$refs.box;
        if (box) box.scrollTop = box.scrollHeight;
      });
    };
  },

  beforeUnmount() {
    tracker.onEvent = null;
  },
};
</script>

<style scoped>
.debug-overlay {
  position: fixed;
  bottom: 16px;
  right: 16px;
  width: 480px;
  background: rgba(0, 0, 0, 0.88);
  border-radius: 8px;
  font-family: monospace;
  font-size: 11px;
  color: #00ff88;
  z-index: 9999;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 24px rgba(0,0,0,0.5);
}

.debug-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 10px;
  border-bottom: 1px solid #333;
  color: #aaa;
}

.debug-header span { flex: 1; }

.debug-header button {
  background: #333;
  color: #ccc;
  border: none;
  border-radius: 4px;
  padding: 2px 8px;
  cursor: pointer;
  font-size: 11px;
}

.debug-box {
  width: 100%;
  height: 300px;
  background: transparent;
  border: none;
  color: #00ff88;
  font-family: monospace;
  font-size: 11px;
  padding: 8px 10px;
  resize: none;
  outline: none;
  white-space: pre;
}
</style>
