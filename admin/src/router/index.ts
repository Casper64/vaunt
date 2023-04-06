import {createRouter, createWebHistory} from 'vue-router'
import {useArticleStore} from '@/stores/article'

import HomeView from '@/views/Home.vue'
import CreateView from '@/views/Create.vue'
import View404 from '@/views/404.vue'
import EditView from '@/views/Edit.vue'
import {useBlockStore} from '@/stores/blocks'

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
                if (article == undefined) {
                    next('/')
                    return
                }

                const blockStore = useBlockStore()
                await blockStore.fetchData(article.id)
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
