<script setup lang="ts">
import ArticleThumbnail from '@/components/ArticleThumbnail.vue';
import { FormKit } from '@formkit/vue';
import { useArticleStore } from '@/stores/article';
import { userCategoryStore } from '@/stores/category';
import { computed, ref } from 'vue';

const articleStore = useArticleStore()
const categoryStore = userCategoryStore()
const searchString = ref('')

const filteredArticles = computed(() => {
    if (searchString.value == '') {
        return articleStore.articles
    } else {
        return articleStore.articles.filter(a => {
            return a.name.toLowerCase().includes(searchString.value.toLowerCase())
        })
    }
})

function getArticleByCategory(id: number) {
    return filteredArticles.value.filter(a => a.category_id == id)
}

</script>

<template>
<div class="home-container">
    <h1>My Articles</h1>
    <div class="utility-bar">
        <router-link to="/admin/create">
            <FormKit type="button" prefix-icon="add">Create Article</FormKit>
        </router-link>
        <div class="search">
            <FormKit 
                type="search" 
                placeholder="Search ..."
                prefix-icon="search"
                v-model="searchString"
            />
        </div>
        <router-link to="/admin/create-category" class="add-category-btn">
            <FormKit type="button" prefix-icon="add">Add Category</FormKit>
        </router-link>
    </div>
    <div class="categories-container">
        <template v-for="category in categoryStore.categories">
            <h1 class="category-name">Category: {{  category.name }}</h1>
            <section class="articles" >
                <template v-for="article in getArticleByCategory(category.id)">
                    <ArticleThumbnail :article-id="article.id"/>
                </template>
            </section>
        </template>
        <h1 class="category-name">Without category:</h1>
        <section class="articles" >
            <template v-for="article in getArticleByCategory(0)">
                <ArticleThumbnail :article-id="article.id"/>
            </template>
        </section>
    </div>
</div>
</template>

<style lang="scss" scoped>

.home-container {
    padding: 50px;
    display: grid;
    justify-items: center;
    width: 100%;
}

.utility-bar {
    margin-top: 20px;
    display: grid;
    grid-template-columns: max-content max-content max-content;
    column-gap: 20px;
    align-items: center;
}

.categories-container {
    margin-top: 20px;
    width: 100%;

    .category-name {
        margin: 20px;
        text-align: center;
    }
}

section.articles {
    width: 100%;
    display: grid;
    grid-template-columns: repeat(auto-fit, 720px);
    justify-content: center;
    row-gap: 50px;
    column-gap: 50px;
   
    &:not(:last-of-type) {
        border-bottom: 1px solid var(--border-color);
        padding: 20px 0;
    }
}

.add-category-btn {
    width: max-content; 
    display: block;
    margin: 20px auto;
}

</style>