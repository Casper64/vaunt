import axios from '@/plugins/axios'
import type { Article } from 'env'
import { defineStore } from 'pinia'

export const useArticleStore = defineStore('article', {
    state: () => {
        return {
            articles: [] as Article[]
        }
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
        get(id: any) {
            return this.articles.find(a => a.id == id)
        },
        async create(data: any) {
            const body = new FormData()
            body.append('name', data.name)
            body.append('description', data.description)

            // create standard title block
            const blocks = `[{"id":"e_sTVYXqiN","type":"heading","data":{"text":"${data.name}","level":1}}]`
            body.append('block_data', blocks)

            // TODO: add image uploads
            // data.thumbnail.forEach((fileItem: any) => {
            //     body.append('thumbnail', fileItem.file)
            // })

            const response = await axios.post('/articles', body)
            this.articles.push(response.data)
            return response.data
        },
        async remove(id: number) {
            await axios.delete(`/articles/${id}`)
            this.articles = this.articles.filter(a => a.id != id)
        }
    }
})