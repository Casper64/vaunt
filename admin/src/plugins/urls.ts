

const BASE_URL = import.meta.env.MODE == 'development' ?
    import.meta.env.VITE_DEV_BASE_URL : window.location.origin

const BASE_API_URL = import.meta.env.MODE == 'development' ?
    import.meta.env.VITE_DEV_BASE_API_URL :  window.location.origin+'/api'

console.log(BASE_URL, BASE_API_URL, import.meta.env.DEV_BASE_API_URL)

export {
    BASE_URL,
    BASE_API_URL
}