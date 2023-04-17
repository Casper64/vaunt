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
    show: boolean
    thumbnail: any
    image_src: string
    created_at: string
    updated_at: string
}

type CreateArticle = Pick<Article, 'name' | 'description' | 'thumbnail'>

type ThemeOptionType = 'Color' | 'ClassList'

interface ThemeOption {
    id: number
    name: string
    option_type: ThemeOptionType
    data: string
}

interface Color {
    name: string
    color: string
}

interface ClassList {
    name: string
    options: Record<string, string>
    selected: string
}