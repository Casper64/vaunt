import axios from '@/plugins/axios'
import type { Category, CreateCategory } from 'env'
import {defineStore} from 'pinia'

export const userCategoryStore = defineStore('category', {
    state: () => {
        return {
            categories: [] as Category[]
        }
    },
    actions: {
        async fetchData() {
            try {
                const response = await axios.get('/categories')
                this.categories = response.data
                return true
            } catch (err) {
                return false
            }
        },
        get(id: any) {
            return this.categories.find(c => c.id == id)
        },
        async create(data: CreateCategory) {
            const body = new FormData()
            body.append('name', data.name)

            const response = await axios.post('/categories', body)
            this.categories.push(response.data)

            return response.data
        }, 
        async remove(id: number) {
            await axios.delete(`/categories/${id}`)
            this.categories = this.categories.filter(c => c.id != id)
        },
        async update(id: number, data: CreateCategory) {
            const currentCategory = this.get(id)

            if (currentCategory) {
                const body = new FormData()
                body.append('name', data.name)
    
                await axios.put(`/categories/${id}`, body)
    
                currentCategory.name = data.name            
            }
        }
    }
})