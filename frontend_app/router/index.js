import { createRouter, createWebHistory } from 'vue-router';
import SurveyPage from '../pages/SurveyPage.vue';
import NotFound from '../pages/404.vue';

const routes = [
  {
    path: '/survey',
    name: 'Survey',
    component: SurveyPage,
  },
  {
    path: '/',
    redirect: '/survey',
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

export default router;
