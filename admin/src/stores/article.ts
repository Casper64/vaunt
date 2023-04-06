import axios from '@/plugins/axios'
import type {Article, CreateArticle}
from 'env'
import {defineStore} from 'pinia'

export const useArticleStore = defineStore('article', {
    state: () => {
        return {articles: [] as Article[]}
    },
    actions: {
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
        async create(data : any) {
            const body = new FormData()
            body.append('name', data.name)
            body.append('description', data.description)

            // create standard title block
            const blocks = `[{"id":"e_sTVYXqiN","type":"heading","data":{"text":"${
                data.name
            }","level":1}}]`
            body.append('block_data', blocks)

            data.thumbnail.forEach((fileItem: any) => {
                body.append('thumbnail-name', fileItem.name)
                body.append('thumbnail', fileItem.file)
            })

            const response = await axios.post('/articles', body)
            this.articles.push(response.data)
            return response.data
        },
        async remove(id : number) {
            await axios.delete(`/articles/${id}`)
            this.articles = this.articles.filter(a => a.id != id)
        },
        async update(id : number, data : CreateArticle) {
            let currentArticle = this.get(id)
            if (currentArticle) {
                const body = new FormData()
                body.append('name', data.name)
                body.append('description', data.description)

                let name = ''
                data.thumbnail.forEach((fileItem : any) => {
                    name = fileItem.name
                    body.append('thumbnail-name', fileItem.name)
                    body.append('thumbnail', fileItem.file)
                })

                await axios.put(`/articles/${id}`, body)
                currentArticle.name = data.name
                currentArticle.description = data.description
                // hardcoded for reactivity
                if (name) {
                    currentArticle.image_src = `uploads/img/${name}`
                }
                return true
            }
            return false
        },
        async publish(article_id : number) { // wait for save
            await new Promise(res => setTimeout(res, 300))
            const response = await axios.get(`/publish?article=${article_id}`)
            const url = new URL(import.meta.env.VITE_API_BASE_URL)
            window.open(url.origin + response.data, '_self')
        }
    }
})
