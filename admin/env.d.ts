/// <reference types="vite/client" />

import axios from 'axios'

declare module 'vue' {
    interface ComponentCustomProperties {
        axios: typeof axios
    }
}

interface Article {
    id: number
    name:  string
    block_data: string
    description: string
    thumbnail?: string
    created_at: string
    updated_at: string
}

type CreateArticle = Pick<Article, 'name' | 'description' | 'thumbnail'>
