<script setup lang="ts">
import { useArticleStore } from '@/stores/article';
import { ref } from 'vue';
import { computed } from 'vue';
import { useRouter } from 'vue-router';

const props = defineProps<{
    articleId: number
}>()

const articleStore = useArticleStore()
const router = useRouter()

const complete = ref(false)

const article = computed(() => {
    return articleStore.get(props.articleId)!
})

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dev']
const updated_date = computed(() => {
    let date = new Date(article.value.updated_at)
    return `${months[date.getMonth()]} ${date.getDate()}`
})

const thumbnailSource = computed(() => {
    return import.meta.env.VITE_BASE_URL+article.value.image_src
})

async function deletePost() {
    if (window.confirm(`Are you sure you want to delete article "${article.value.name}"?`)) {
        try {
            await articleStore.remove(article.value.id)
            router.push('/admin')
        } catch (err) {
            console.log(err)
        }
    }
}

async function publishHandler() {
    try {
        await articleStore.publish(article.value.id)
    } catch (err) {}
    finally {
        complete.value = true
    }
}


</script>

<template>
    <div class="article-preview">
        <div class="article-card">
            <h1>{{ article.name }}</h1>
            <p class="description">{{  article.description }}</p>
            <p class="date">{{  updated_date }}</p>
            <div class="category-pill">category</div>
        </div>
        <div class="thumbnail">
            <img alt="thumbnail" :src="thumbnailSource">
        </div>
        <div class="buttons-container">
            <FormKit type="button" @click="publishHandler">Publish</FormKit>
            <router-link :to="`/admin/edit/${article.id}`">
                <FormKit type="button">Edit</FormKit>
            </router-link>
            <router-link :to="`/admin/settings/${article.id}`">
                <FormKit type="button">Settings</FormKit>
            </router-link>
            <FormKit type="button" @click="deletePost">Delete</FormKit>
        </div>
    </div>
</template>

<style lang="scss" scoped>

.article-preview {
    display: grid;
    grid-template-columns: max-content 300px;
    grid-template-rows: max-content;
    row-gap: 20px;
    column-gap: 20px;
}

.article-card {
    width: 400px;
    height: 180px;
    padding: 20px;
    border-radius: 5px;
    border: 1px solid var(--border-color);
    background-color: white;
    display: grid;
    row-gap: 10px;
    grid-template-rows: auto 1fr auto;
    position: relative;

    h1 {
        font-size: 32px;
        font-weight: 700;
    }

    p.description {
        font-size: 14px;
    }
    p.date {
        font-size: 12px;
        color: var(--text);
    }

    .category-pill {
        position: absolute;
        right: 20px;
        bottom: 20px;
    }
}

.buttons-container {
    grid-column: span 2;
    display: grid;
    grid-auto-flow: column;
    justify-content: center;
    column-gap: 20px;
}

.thumbnail {
    max-width: 300px;
    max-height: 180px;
    display: grid;
    justify-items: center;
    align-items: center;

    img {
        max-width: 100%;
        max-height: 180px;
        // aspect-ratio: ;
    }
}

</style>