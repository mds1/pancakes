import { RouteConfig } from 'vue-router';

const routes: RouteConfig[] = [
  {
    path: '/',
    component: () => import('layouts/BaseLayout.vue'),
    children: [
      { name: 'home', path: '', component: () => import('pages/Home.vue') },
      {
        name: 'buttermilk',
        path: '/buttermilk',
        component: () => import('pages/TierButtermilk.vue'),
      },
      {
        name: 'chocolateChip',
        path: '/chocolateChip',
        component: () => import('pages/TierChocolateChip.vue'),
      },
      {
        name: 'returns',
        path: '/returns',
        component: () => import('pages/Returns.vue'),
      },
    ],
  },

  // Always leave this as last one,
  // but you can also remove it
  {
    path: '*',
    component: () => import('pages/Error404.vue'),
  },
];

export default routes;
