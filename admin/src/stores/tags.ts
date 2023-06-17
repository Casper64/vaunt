import axios from '@/plugins/axios'
import type { Tag } from 'env'
import {defineStore} from 'pinia'

export const useTagStore = defineStore('tag', {
    state: () => {
        return {
            tags: [] as Tag[],
        }
    },
    actions: {
        async fetchData() {
            try {
                const response = await axios.get('/tags')
                this.tags = response.data
                return true
            } catch (err) {
                return false
            }
        },
        async fetch(article: number) {
            try {
                const response = await axios.get(`/tags/${article}`)
                this.tags.push(...response.data)
                return true
            } catch (err) {
                return false
            }
        },
        get(article_id: number) {
            return this.tags.filter(t => t.article_id == article_id)
        },
        baseTags() {
            return this.get(0)
        },
        getBaseTag(name: string) {
            return this.tags.find(x => x.article_id == 0 && x.name == name)
        },
        async update(article_id: number) {
            // await axios.post(`/tags/${article_id}`, JSON.stringify(this.currentTags))
        },
        async create(name: string, color: string, article: number = 0) {
            const body = new FormData()
            body.append('name', name)
            body.append('color', color)

            // first create the tag
            const response = await axios.post('/tags', body)
            let baseTag = response.data
            this.tags.push(baseTag)

            if (article) {
                await this.addToArticle(article, baseTag.id)
            }
        },
        async addToArticle(article: number, tag: number) {
            const body = new FormData()
            body.append('article', String(article))
            body.append('tag_id', String(tag))

            const response = await axios.post(`/tags/${article}`, body)
            this.tags.push(response.data)
        },
        async deleteTag(tag: number, article: number = 0) {
            await axios.delete(`/tags/${tag}`)
            await this.fetchData()
            if (article) {
                await this.fetch(article)
            }
        }
    },
})