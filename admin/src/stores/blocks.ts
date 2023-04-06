import axios from '@/plugins/axios'
import type { OutputBlockData } from '@editorjs/editorjs'
import { defineStore } from 'pinia'

export const useBlockStore = defineStore('block', {
    state: () => {
        return {
            blocks: [] as OutputBlockData<string, any>[],
            names: ['heading', 'paragraph', 'image', 'link', 'quote', 'embed', 'table'],
            icons: ['h1','text', 'img', 'link', 'quote', 'embed', 'table']
        }
    },
    actions: {
        async fetchData(article_id: any) {
            try {
                const response = await axios.get(`/blocks?article=${article_id}`)
                this.blocks = response.data
                for (let i = 0; i < this.blocks.length; i++) {
                    this.blocks[i].data = JSON.parse(this.blocks[i].data)
                }
                return true
            } catch (err) {
                return false
            }
        },
        async save(article_id: any) {
            // js is weird so array has to be cloned
            const blocks = [] as OutputBlockData<string, any>[]
            for (let i = 0; i < this.blocks.length; i++) {
                // clone obj
                blocks.push(Object.assign({}, this.blocks[i]))
                blocks[i].data = JSON.stringify(blocks[i].data)
            }

            const body = JSON.stringify(blocks)
            const response = await axios.post(`/blocks?article=${article_id}`, body)
            console.log(response)
        }
    }
})