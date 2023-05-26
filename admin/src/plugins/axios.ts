import axios from 'axios'
import { BASE_API_URL } from './urls'

const axiosInstance = axios.create({
    baseURL: BASE_API_URL,
    // fix cors when using dev server
    withCredentials: true,
    headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Credentials': 'true',
    }
})
// have to specify `withCredentials` 3 times, poorly maintained library but still the best :/
// welcome to the world of NPM -_-
axiosInstance.defaults.withCredentials = true

export default axiosInstance