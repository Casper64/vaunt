import axios from '@/plugins/axios'
import type { OutputBlockData } from '@editorjs/editorjs'
import { defineStore } from 'pinia'

export const useBlockStore = defineStore('block', {
    state: () => {
        return {
            blocks: [] as OutputBlockData<string, any>[],
            // map names to icons. To future me: convert this shit into a hashmap
            names: ['heading', 'paragraph', 'image', 'linkTool', 'quote', 'embed', 'table', 'code'],
            icons: ['h1','text', 'img', 'link', 'quote', 'embed', 'table', 'code']
        }
    },
    actions: {
        // fetchData returns true when all blocks have been successfully fetched, 
        // this boolean is used by the router
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
            await axios.post(`/blocks?article=${article_id}`, body)
        },
        async removeImage(src: string) {
            const body = new FormData()
            // get only part after the last "/"
            body.append('image', src.split('/').pop() || '')

            body.append('article', window.location.pathname.split('/').pop()!)

            await axios.post('delete-image', body)
        }
    }
})