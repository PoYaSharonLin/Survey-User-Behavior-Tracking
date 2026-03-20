<template>
  <div class="slider-bar-wrapper" ref="sliderEl" data-track="slider">
    <div class="slider-track" @mousedown="startDrag" @touchstart.prevent="startTouchDrag">
      <div class="slider-fill" :style="{ width: fillPercent + '%' }"></div>
      <div
        class="slider-thumb"
        :style="{ left: fillPercent + '%' }"
        role="slider"
        :aria-valuenow="modelValue"
        :aria-valuemin="min"
        :aria-valuemax="max"
        tabindex="0"
        @keydown="onKeydown"
      ></div>
    </div>
    <div class="slider-labels">
      <span>{{ minLabel || min }}</span>
      <span class="slider-current-value">{{ modelValue }}</span>
      <span>{{ maxLabel || max }}</span>
    </div>
  </div>
</template>

<script>
import tracker from '@/lib/tracker';

export default {
  name: 'SliderBar',

  props: {
    modelValue: { type: Number, default: 50 },
    min:        { type: Number, default: 0 },
    max:        { type: Number, default: 100 },
    step:       { type: Number, default: 1 },
    minLabel:   { type: String, default: '' },
    maxLabel:   { type: String, default: '' },
  },

  emits: ['update:modelValue', 'change'],

  computed: {
    fillPercent() {
      return ((this.modelValue - this.min) / (this.max - this.min)) * 100;
    },
  },

  methods: {
    clamp(v) {
      return Math.min(this.max, Math.max(this.min, v));
    },

    valueFromClientX(clientX) {
      const track = this.$refs.sliderEl.querySelector('.slider-track');
      const rect  = track.getBoundingClientRect();
      const ratio = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
      const raw   = this.min + ratio * (this.max - this.min);
      return Math.round(raw / this.step) * this.step;
    },

    emit(val) {
      const clamped = this.clamp(val);
      this.$emit('update:modelValue', clamped);
      this.$emit('change', clamped);
      tracker.recordSlider(clamped, '.slider-bar-wrapper');
    },

    startDrag(e) {
      this.emit(this.valueFromClientX(e.clientX));
      const onMove = (ev) => this.emit(this.valueFromClientX(ev.clientX));
      const onUp   = () => {
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup',   onUp);
      };
      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup',   onUp);
    },

    startTouchDrag(e) {
      const onMove = (ev) => this.emit(this.valueFromClientX(ev.touches[0].clientX));
      const onEnd  = () => {
        window.removeEventListener('touchmove', onMove);
        window.removeEventListener('touchend',  onEnd);
      };
      window.addEventListener('touchmove', onMove, { passive: true });
      window.addEventListener('touchend',  onEnd);
    },

    onKeydown(e) {
      const step = e.shiftKey ? this.step * 10 : this.step;
      if      (e.key === 'ArrowRight' || e.key === 'ArrowUp')   this.emit(this.modelValue + step);
      else if (e.key === 'ArrowLeft'  || e.key === 'ArrowDown')  this.emit(this.modelValue - step);
      else if (e.key === 'Home') this.emit(this.min);
      else if (e.key === 'End')  this.emit(this.max);
    },
  },
};
</script>

<style scoped>
.slider-bar-wrapper {
  width: 100%;
  user-select: none;
  padding: 8px 0;
}

.slider-track {
  position: relative;
  height: 8px;
  background: #e0e0e0;
  border-radius: 4px;
  cursor: pointer;
}

.slider-fill {
  position: absolute;
  left: 0;
  top: 0;
  height: 100%;
  background: linear-gradient(90deg, #6c63ff, #48cae4);
  border-radius: 4px;
  transition: width 0.05s;
}

.slider-thumb {
  position: absolute;
  top: 50%;
  transform: translate(-50%, -50%);
  width: 22px;
  height: 22px;
  background: #fff;
  border: 3px solid #6c63ff;
  border-radius: 50%;
  box-shadow: 0 2px 8px rgba(108, 99, 255, 0.35);
  cursor: grab;
  transition: left 0.05s, box-shadow 0.2s;
  outline: none;
}

.slider-thumb:focus {
  box-shadow: 0 0 0 4px rgba(108, 99, 255, 0.25);
}

.slider-thumb:active {
  cursor: grabbing;
}

.slider-labels {
  display: flex;
  justify-content: space-between;
  margin-top: 10px;
  font-size: 0.85rem;
  color: #888;
}

.slider-current-value {
  font-weight: 700;
  color: #6c63ff;
  font-size: 1rem;
}
</style>
