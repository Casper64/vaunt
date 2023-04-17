import {createRouter, createWebHistory} from 'vue-router'
import {useArticleStore} from '@/stores/article'

import HomeView from '@/views/Home.vue'
import CreateView from '@/views/Create.vue'
import View404 from '@/views/404.vue'
import EditView from '@/views/Edit.vue'
import {useBlockStore} from '@/stores/blocks'
import ThemeView from '@/views/Theme.vue'
import { useThemeStore } from '@/stores/theme'

// In the built app all routes will be after the route `/admin` so we prepend
// it now in the router. This avoids many headaches in production and this way
// it is not neceassary to do any fancy path transformation with static assets.

const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    routes: [
        {
            path: '/admin',
            name: 'home',
            component: HomeView,
            async beforeEnter(to, from, next) {
                const store = useArticleStore()
                await store.fetchData()
                next()
            }
        }, {
            path: '/admin/create',
            name: 'create',
            component: CreateView
        }, {
            path: '/admin/edit/:id',
            name: 'edit',
            component: EditView,
            async beforeEnter(to, from, next) {
                const articleStore = useArticleStore()
                await articleStore.fetchData()
                const article = articleStore.get(to.params['id'])

                // first check if article exists
                if (article == undefined) {
                    next('/')
                    return
                }
                
                // then fetch all blocks which should at least return `[]`
                const blockStore = useBlockStore()
                await blockStore.fetchData(article.id)
                next()
            }
        }, {
            path: '/admin/theme',
            name: 'theme',
            component: ThemeView,
            async beforeEnter(to, from, next) {
                const store = useThemeStore()
                await store.fetchData()
                next()
            }
        }, {
            path: '/:pathMatch(.*)*',
            name: 'NotFound',
            component: View404,
        }
    ]
})

export default router
