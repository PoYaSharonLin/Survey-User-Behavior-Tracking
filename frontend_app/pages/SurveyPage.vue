<template>
  <div class="survey-wrapper">
    <BehaviorTracker>
      <div class="survey-page">
        <!-- Header -->
        <header class="survey-header">
          <h1 class="survey-title">Survey</h1>
          <p class="survey-subtitle" v-if="userId">
            Your session ID: <code class="uid-tag">{{ userId }}</code>
          </p>
          <p class="survey-subtitle warning" v-else>
            ⚠ No user ID found. Please access this page via the link provided to you.
          </p>
        </header>

        <!-- Survey body -->
        <main v-if="userId" class="survey-body">
          <!-- Q1: Satisfaction slider -->
          <section class="survey-section" data-track="q1-satisfaction">
            <h2 class="question-label">
              1. How satisfied are you with the product overall?
            </h2>
            <p class="scale-hint">
              <span>Not at all satisfied</span>
              <span>Extremely satisfied</span>
            </p>
            <SliderBar
              v-model="answers.satisfaction"
              :min="1"
              :max="10"
              :step="1"
              minLabel="1"
              maxLabel="10"
            />
          </section>

          <!-- Q2: Ease of use slider -->
          <section class="survey-section" data-track="q2-ease">
            <h2 class="question-label">
              2. How easy was it to use the product?
            </h2>
            <p class="scale-hint">
              <span>Very difficult</span>
              <span>Very easy</span>
            </p>
            <SliderBar
              v-model="answers.easeOfUse"
              :min="1"
              :max="10"
              :step="1"
              minLabel="1"
              maxLabel="10"
            />
          </section>

          <!-- Q3: Recommendation slider -->
          <section class="survey-section" data-track="q3-recommend">
            <h2 class="question-label">
              3. How likely are you to recommend this product to a friend?
            </h2>
            <p class="scale-hint">
              <span>Not likely</span>
              <span>Very likely</span>
            </p>
            <SliderBar
              v-model="answers.recommend"
              :min="0"
              :max="10"
              :step="1"
              minLabel="0 (Not at all)"
              maxLabel="10 (Definitely)"
            />
          </section>

          <!-- Q4: Open feedback (hoverable) -->
          <section class="survey-section" data-track="q4-feedback">
            <h2 class="question-label">
              4. Any additional feedback? <span class="optional">(Optional)</span>
            </h2>
            <textarea
              v-model="answers.feedback"
              class="feedback-textarea"
              placeholder="Type your thoughts here…"
              rows="4"
              data-track="feedback-textarea"
            />
          </section>

          <!-- Submit -->
          <div class="submit-row">
            <button
              class="submit-btn"
              data-track="submit-button"
              :disabled="submitted"
              @click="submit"
            >
              {{ submitted ? '✓ Submitted — Thank you!' : 'Submit Survey' }}
            </button>
          </div>

          <!-- Share URL panel (for other apps / researchers) -->
          <div v-if="shareUrl" class="share-panel" data-track="share-panel">
            <p class="share-label">Session link (copy for reference):</p>
            <div class="share-url-row">
              <code class="share-url-text">{{ shareUrl }}</code>
              <button class="copy-btn" @click="copyShareUrl">
                {{ copied ? 'Copied!' : 'Copy' }}
              </button>
            </div>
          </div>
        </main>

        <!-- No UID state -->
        <div v-else class="no-uid-notice">
          <p>Please open the link you received with a <code>?uid=…</code> parameter.</p>
        </div>
      </div>
    </BehaviorTracker>
  </div>
</template>

<script>
import BehaviorTracker from '@/components/BehaviorTracker.vue';
import SliderBar       from '@/components/SliderBar.vue';
import session         from '@/lib/session';

export default {
  name: 'SurveyPage',

  components: { BehaviorTracker, SliderBar },

  data() {
    return {
      userId:    null,
      shareUrl:  null,
      submitted: false,
      copied:    false,
      answers: {
        satisfaction: 5,
        easeOfUse:    5,
        recommend:    5,
        feedback:     '',
      },
    };
  },

  async created() {
    // Initialise session (reads ?uid= from URL, registers with backend)
    this.userId   = await session.init();
    this.shareUrl = session.getShareUrl();
  },

  methods: {
    async submit() {
      // Simple client-side guard
      if (this.submitted) return;
      this.submitted = true;

      // Optionally mark session as ended
      try {
        await import('axios').then(({ default: axios }) =>
          axios.post('/api/survey/session', {
            user_id: this.userId,
            metadata: { answers: this.answers, submitted_at: new Date().toISOString() },
          })
        );
      } catch (_) { /* non-fatal */ }
    },

    copyShareUrl() {
      navigator.clipboard.writeText(this.shareUrl).then(() => {
        this.copied = true;
        setTimeout(() => { this.copied = false; }, 2000);
      });
    },
  },
};
</script>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;900&display=swap');

* { box-sizing: border-box; }

.survey-wrapper {
  min-height: 100vh;
  background: linear-gradient(135deg, #f0f4ff 0%, #faf0ff 100%);
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding: 48px 16px 80px;
  font-family: 'Inter', sans-serif;
}

.survey-page {
  width: 100%;
  max-width: 680px;
  background: #fff;
  border-radius: 20px;
  box-shadow: 0 8px 48px rgba(108, 99, 255, 0.12);
  overflow: hidden;
}

/* ── Header ──────────────────────────────────────────────── */
.survey-header {
  background: linear-gradient(135deg, #6c63ff 0%, #48cae4 100%);
  padding: 40px 40px 32px;
  color: #fff;
}

.survey-title {
  font-size: 2.2rem;
  font-weight: 900;
  margin: 0 0 8px;
  letter-spacing: -0.5px;
}

.survey-subtitle {
  margin: 0;
  font-size: 0.9rem;
  opacity: 0.85;
}

.survey-subtitle.warning { color: #ffe082; }

.uid-tag {
  background: rgba(255,255,255,0.2);
  padding: 2px 8px;
  border-radius: 4px;
  font-family: monospace;
}

/* ── Body ───────────────────────────────────────────────── */
.survey-body {
  padding: 40px;
}

.survey-section {
  margin-bottom: 40px;
  padding: 28px;
  border: 1.5px solid #ede8ff;
  border-radius: 14px;
  transition: box-shadow 0.2s;
}

.survey-section:hover {
  box-shadow: 0 4px 20px rgba(108, 99, 255, 0.1);
}

.question-label {
  font-size: 1.05rem;
  font-weight: 600;
  color: #333;
  margin: 0 0 16px;
}

.scale-hint {
  display: flex;
  justify-content: space-between;
  font-size: 0.78rem;
  color: #aaa;
  margin-bottom: 10px;
}

.optional {
  font-weight: 400;
  color: #aaa;
  font-size: 0.85rem;
}

.feedback-textarea {
  width: 100%;
  border: 1.5px solid #e0e0e0;
  border-radius: 10px;
  padding: 14px;
  font-size: 0.95rem;
  font-family: 'Inter', sans-serif;
  resize: vertical;
  transition: border-color 0.2s;
  outline: none;
  color: #333;
}

.feedback-textarea:focus {
  border-color: #6c63ff;
  box-shadow: 0 0 0 3px rgba(108,99,255,0.15);
}

/* ── Submit ─────────────────────────────────────────────── */
.submit-row {
  text-align: center;
  margin-bottom: 32px;
}

.submit-btn {
  background: linear-gradient(135deg, #6c63ff, #48cae4);
  color: #fff;
  border: none;
  border-radius: 50px;
  padding: 14px 48px;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
  transition: transform 0.15s, box-shadow 0.15s, opacity 0.2s;
  letter-spacing: 0.5px;
}

.submit-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(108, 99, 255, 0.35);
}

.submit-btn:disabled {
  opacity: 0.7;
  cursor: default;
}

/* ── Share panel ─────────────────────────────────────────── */
.share-panel {
  margin-top: 8px;
  padding: 20px;
  background: #f8f7ff;
  border-radius: 12px;
  border: 1.5px solid #ede8ff;
}

.share-label {
  font-size: 0.8rem;
  color: #888;
  margin: 0 0 8px;
}

.share-url-row {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.share-url-text {
  flex: 1;
  font-size: 0.82rem;
  color: #6c63ff;
  word-break: break-all;
  background: #fff;
  padding: 6px 10px;
  border-radius: 6px;
  border: 1px solid #ddd;
}

.copy-btn {
  background: #6c63ff;
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 8px 16px;
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.2s;
}

.copy-btn:hover { background: #5a52e0; }

/* ── No UID notice ───────────────────────────────────────── */
.no-uid-notice {
  padding: 40px;
  text-align: center;
  color: #888;
}
</style>
