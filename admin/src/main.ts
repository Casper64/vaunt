import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { plugin, defaultConfig } from '@formkit/vue'

import App from '@/App.vue'
import router from '@/router'
import VueAxios from 'vue-axios'
import axios from 'axios'

import './assets/admin/styles/main.scss'
import { BASE_URL } from './plugins/urls'

const app = createApp(App)

app.use(plugin, defaultConfig({
    theme: 'genesis'
}))

app.use(createPinia())
app.use(router)

// prepend the base api url to each request
axios.defaults.baseURL = BASE_URL


app.use(VueAxios, axios)
app.provide('axios', app.config.globalProperties.axios)  // provide 'axios' to vue

app.mount('#app')