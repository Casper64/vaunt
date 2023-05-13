/// <reference types="vite/client" />

import axios from 'axios'

declare module 'vue' {
    interface ComponentCustomProperties {
        axios: typeof axios
    }
}

interface Category {
    id: number
    name: string
}

type CreateCategory = Pick<Category, 'name'>

interface Article {
    id: number
    name:  string
    category_id: number
    block_data: string
    description: string
    show: boolean
    thumbnail: any
    image_src: string
    created_at: string
    updated_at: string
}

type CreateArticle = Pick<Article, 'name' | 'description' | 'thumbnail' | 'category_id'>

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

interface Tag {
    id: number;
    article_id: number;
    color: string;
    name: string;
}