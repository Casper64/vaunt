import axios from '@/plugins/axios'
import { BASE_API_URL } from '@/plugins/urls'
import type {Article, CreateArticle} from 'env'
import {defineStore} from 'pinia'

export const useArticleStore = defineStore('article', {
    state: () => {
        return {articles: [] as Article[]}
    },
    actions: {
        // fetchData returns true when all articles have been successfully fetched, 
        // this boolean is used by the router
        async fetchData() {
            try {
                const response = await axios.get('/articles')
                this.articles = response.data
                return true
            } catch (err) {
                return false
            }
        },
        get(id : any) {
            return this.articles.find(a => a.id == id)
        },
        async create(data: any) {
            for (const key in data) {
                if (typeof data[key] == 'string') {
                    data[key] = data[key].replace(/\r/g, "");
                }
            }

            const body = new FormData()
            body.append('name', data.name)
            body.append('description', data.description)
            body.append('category', String(data.category_id) || '0')


            // create standard title block with the text equal to the article name
            const blocks = `[]`

            body.append('block_data', blocks)

            // add file data
            data.thumbnail.forEach((fileItem: any) => {
                body.append('thumbnail-name', fileItem.name)
                body.append('thumbnail', fileItem.file)
            })

            const response = await axios.post('/articles', body)
            this.articles.push(response.data)

            return response.data
        },
        // delete an article with `id`
        async remove(id : number) {
            await axios.delete(`/articles/${id}`)
            this.articles = this.articles.filter(a => a.id != id)
        },
        // update an articles name, desecription and/or thumbnail image
        async update(id : number, data : any) {
            for (const key in data) {
                if (typeof data[key] == 'string') {
                    data[key] = data[key].replace(/\r/g, "");
                }
            }

            let currentArticle = this.get(id)
            if (currentArticle) {
                const body = new FormData()
                body.append('name', data.name)
                body.append('description', data.description)
                body.append('category_id', String(data.category_id))

                let name = ''
                data.thumbnail.forEach((fileItem : any) => {
                    name = fileItem.name
                    body.append('thumbnail-name', fileItem.name)
                    body.append('thumbnail', fileItem.file)
                })
                
                await axios.put(`/articles/${id}`, body)

                // hardcoded for reactivity without page reload
                currentArticle.name = data.name
                currentArticle.description = data.description
                currentArticle.category_id = data.category_id || 0
                if (name) {
                    currentArticle.image_src = `/uploads/img/${name}`
                }
                return true
            }
            return false
        },
        async changeCategory(id: number, category: number) {
            const currentArticle = this.get(id)

            if (currentArticle) {
                const body = new FormData()
            
                body.append('category', String(category))
                await axios.put(`/articles/${id}`, body)

                currentArticle.category_id = category
            }
        },
        async publish(article_id : number) { 
            // wait for save
            await new Promise(res => setTimeout(res, 300))

            const response = await axios.get(`/publish?article=${article_id}`)
            const url = new URL(BASE_API_URL)
            
            // if we would use `router.push` vue router would handle the route
            // and we want it to redirect to the vweb application
            window.open(url.origin + response.data, '_self')
        },
        // Toggle visibility of an article: whether to show it on the front page or not
        async changeVisibility(article_id: number) {
            const body = new FormData()

            // toggle show field
            let show = this.get(article_id)!.show
            body.append('show', String(!show))

            await axios.put(`/articles/${article_id}`, body)

            // hardcoded for reactivity without page reload
            this.get(article_id)!.show = !show
        }
    }
})
