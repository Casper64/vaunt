import axios from '@/plugins/axios'
import type { ThemeOption, Color, ClassList } from 'env'
import {defineStore} from 'pinia'

export const useThemeStore = defineStore('theme', {
    state: () => {
        return { 
            colors: {} as Record<string, string>,
            classLists: {} as Record<string, ClassList>
        }
    },
    actions: {
        async fetchData() {
            try {
                let response = await axios.get('/theme/color')
                this.colors = response.data
                response = await axios.get('/theme/classlist')
                this.classLists = response.data

                console.log(this.colors, this.classLists)
            } catch (err) {
                console.log(err)
            }
        }
    }
})