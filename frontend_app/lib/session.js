/**
 * session.js
 *
 * Manages the survey user session:
 * - Reads the unique user ID from the URL query param (?uid=...)
 * - Persists it in localStorage so it survives navigation without the param
 * - Registers the session with the backend on first visit
 */

import axios from 'axios';

const USER_ID_KEY    = 'survey_user_id';
const ORIG_URL_KEY   = 'survey_original_url';

const session = {
  /**
   * Called on app boot. Extracts uid from URL if present,
   * falls back to localStorage, then registers the session with the backend.
   * Returns the user_id string or null if none found.
   */
  async init() {
    const params = new URLSearchParams(window.location.search);
    const urlUid = params.get('uid');

    if (urlUid) {
      localStorage.setItem(USER_ID_KEY, urlUid);
      localStorage.setItem(ORIG_URL_KEY, window.location.href);
    }

    const userId = this.getUserId();
    if (!userId) return null;

    // Register (or resume) the session server-side
    try {
      const resp = await axios.post('/api/survey/session', {
        user_id:      userId,
        original_url: localStorage.getItem(ORIG_URL_KEY) || window.location.href,
        metadata: {
          user_agent: navigator.userAgent,
          referrer:   document.referrer,
        },
      });

      if (resp.data?.data?.share_url) {
        localStorage.setItem('survey_share_url', resp.data.data.share_url);
      }
    } catch (err) {
      console.warn('[session] Could not register session with backend:', err.message);
    }

    return userId;
  },

  getUserId() {
    return localStorage.getItem(USER_ID_KEY) || null;
  },

  getShareUrl() {
    return localStorage.getItem('survey_share_url') || null;
  },

  clear() {
    localStorage.removeItem(USER_ID_KEY);
    localStorage.removeItem(ORIG_URL_KEY);
    localStorage.removeItem('survey_share_url');
  },
};

export default session;
