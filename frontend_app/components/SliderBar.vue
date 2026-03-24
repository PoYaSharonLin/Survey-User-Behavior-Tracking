<template>
  <div class="slider-bar-wrapper" data-track="slider">
    <div class="slider-input-container" :class="{ disabled: finished }">
      <input
        type="range"
        class="native-slider"
        :min="min"
        :max="max"
        :step="step"
        v-model.number="internalValue"
        @input="onInput"
        @change="onFinish"
        :disabled="finished"
      >
    </div>
    <div class="slider-ticks">
      <span>1</span>
      <span>7</span>
    </div>
    <div class="slider-labels">
      <span class="label-min">{{ minLabel }}</span>
      <span class="label-max">{{ maxLabel }}</span>
    </div>
  </div>
</template>

<script>
import tracker from '@/lib/tracker';

export default {
  name: 'SliderBar',

  props: {
    modelValue: { type: Number, default: 4 },
    min:        { type: Number, default: 1 },
    max:        { type: Number, default: 7 },
    step:       { type: Number, default: 1 },
    minLabel:      { type: String, default: '' },
    maxLabel:      { type: String, default: '' },
    questionIndex: { type: Number, default: 0 },
  },

  emits: ['update:modelValue', 'change'],

  data() {
    return {
      internalValue: this.modelValue,
      finished:      false,
    };
  },

  watch: {
    modelValue(newVal) {
      if (!this.finished) this.internalValue = newVal;
    },
  },

  methods: {
    onInput() {
      if (this.finished) return;
      // Use the user-defined 30ms lag
      setTimeout(() => {
        this.emit(this.internalValue);
      }, 30);
    },

    onFinish() {
      if (this.finished) return;
      this.finished = true;
      this.emit(this.internalValue);
    },

    emit(val) {
      this.$emit('update:modelValue', val);
      this.$emit('change', val);
      tracker.recordSlider(val, `.native-slider-${this.questionIndex + 1}`);
    },
  },
};
</script>

<style scoped>
.slider-bar-wrapper {
  width: 100%;
  user-select: none;
}

.slider-input-container {
  width: 100%;
  padding: 10px 0;
}

.native-slider {
  display: block;
  width: 100%;
  margin: 0;
  cursor: pointer;
  height: 8px;
  background: #e0e0e0;
  border-radius: 4px;
  outline: none;
  -webkit-appearance: none;
}

.native-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 22px;
  height: 22px;
  background: #6c63ff;
  border-radius: 50%;
  box-shadow: 0 2px 8px rgba(108, 99, 255, 0.3);
  cursor: grab;
  transition: transform 0.1s;
}

.slider-input-container.disabled .native-slider {
  opacity: 0.5;
  cursor: default;
}

.slider-input-container.disabled .native-slider::-webkit-slider-thumb {
  cursor: default;
  box-shadow: none;
  background: #aaa;
}

.slider-ticks {
  display: flex;
  justify-content: space-between;
  margin-top: 8px;
  padding: 0;
  font-size: 0.95rem;
  font-weight: 700;
  color: #bbb;
}

.slider-ticks span {
  flex: 1;
}

.slider-ticks span:first-child { text-align: left; }
.slider-ticks span:last-child { text-align: right; }

.slider-labels {
  display: flex;
  justify-content: space-between;
  margin-top: 6px;
  font-size: 0.78rem;
  color: #999;
  line-height: 1.4;
}

.label-min { text-align: left; max-width: 48%; }
.label-max { text-align: right; max-width: 48%; }
</style>
