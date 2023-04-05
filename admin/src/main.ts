import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { plugin, defaultConfig } from '@formkit/vue'
// import { createHead } from "@vueuse/head"

import App from '@/App.vue'
import router from '@/router'
import VueAxios from 'vue-axios'
// import Vue3TouchEvents from 'vue3-touch-events'
import axios from 'axios'

import './assets/admin/styles/main.scss'

const app = createApp(App)

app.use(plugin, defaultConfig({
    theme: 'genesis'
}))

// const head = createHead()
// app.use(head)
app.use(createPinia())
app.use(router)

axios.defaults.baseURL = import.meta.env.VITE_API_BASE_URL
// axios.defaults.headers['Access-Control-Allow-Origin'] = '*'
// axios.defaults.headers['Access-Control-Allow-Credentials'] = 'true'

app.use(VueAxios, axios)
app.provide('axios', app.config.globalProperties.axios)  // provide 'axios'

app.mount('#app')