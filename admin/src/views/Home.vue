<script setup lang="ts">
import ArticleThumbnail from '@/components/ArticleThumbnail.vue';
import { FormKit } from '@formkit/vue';
import { useArticleStore } from '@/stores/article';

const articleStore = useArticleStore()

</script>

<template>
<div class="home-container">
    <h1>My Articles</h1>
    <div class="utility-bar">
        <div class="search">
            <FormKit 
                type="search" 
                placeholder="Search ..."
                prefix-icon="search"
            />
        </div>
        <!-- <router-link to="/create" class="edit-button">Create</router-link> -->
        <router-link to="/create">
            <FormKit type="button" prefix-icon="add">Create</FormKit>
        </router-link>
    </div>
    <section class="articles">
        <template v-for="article in articleStore.articles">
            <ArticleThumbnail :article-id="article.id"/>
        </template>
    </section>
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
    grid-template-columns: max-content max-content;
    column-gap: 20px;
    align-items: center;
}

section.articles {
    width: 100%;
    margin-top: 20px;
    display: grid;
    grid-template-columns: repeat(auto-fill, 720px);
    justify-content: center;
    row-gap: 50px;
    column-gap: 50px;
}

</style>