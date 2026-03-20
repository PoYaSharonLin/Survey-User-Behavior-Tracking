<template>
  <!-- All surveyed content is wrapped here; tracker attaches to this root div -->
  <div class="behavior-tracker-root" ref="root">
    <slot />
  </div>
</template>

<script>
import tracker from '@/lib/tracker';
import session from '@/lib/session';

export default {
  name: 'BehaviorTracker',

  computed: {
    userShareUrl() {
      return session.getShareUrl();
    },
  },

  async mounted() {
    const userId = session.getUserId();
    if (userId) {
      tracker.start(userId);
    }
  },

  beforeUnmount() {
    tracker.stop();
  },
};
</script>

<style scoped>
.behavior-tracker-root {
  width: 100%;
  height: 100%;
}
</style>
