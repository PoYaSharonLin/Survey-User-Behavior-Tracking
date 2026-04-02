import { createRouter, createWebHistory } from 'vue-router';
import PracticePage from '../pages/PracticePage.vue';
import SurveyPage from '../pages/SurveyPage.vue';
import NotFound from '../pages/404.vue';

const routes = [
  {
    path: '/practice',
    name: 'Practice',
    component: PracticePage,
  },
  {
    path: '/survey',
    name: 'Survey',
    component: SurveyPage,
  },
  {
    path: '/',
    redirect: '/practice',
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: NotFound,
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

// Guard: anyone who opens /survey directly is sent to /practice first,
// unless they already confirmed the practice question in this browser.
router.beforeEach((to) => {
  if (to.name === 'Survey' && !localStorage.getItem('survey_practice_done')) {
    return { name: 'Practice', query: to.query };
  }
});

export default router;
