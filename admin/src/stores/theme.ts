import axios from '@/plugins/axios'
import type { ThemeOption, Color, ClassList } from 'env'
import {defineStore} from 'pinia'

export const useThemeStore = defineStore('theme', {
    state: () => {
        return { 
            colors: {} as Record<string, string>,
            classLists: {} as Record<string, ClassList>,
            swatches: [] as string[],
        }
    },
    actions: {
        async fetchData() {
            try {
                let p1 = this.fetchColors()
                let p2 = this.fetchClasslists()
                await Promise.all([p1, p2])
            } catch (err) {}
        },
        async fetchColors() {
            try {
                let response = await axios.get('/theme/color')
                this.colors = response.data
                this.swatches = Object.values(this.colors)
                this.swatches.length = 10
            }
            catch (err) {}
        },
        async fetchClasslists() {
            try {
                let response = await axios.get('/theme/classlist')
                this.classLists = response.data
            }
            catch (err) {}
        },
        addSwatch(color: string) {
            this.swatches.splice(0, 0, color)
            if (this.swatches.length > 14) {
                this.swatches.pop()
            } 
        }
    }
})