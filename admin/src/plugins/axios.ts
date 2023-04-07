import axios from 'axios'

const axiosInstance = axios.create({
    baseURL: import.meta.env.VITE_API_BASE_URL,
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