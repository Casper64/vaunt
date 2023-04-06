<script setup lang="ts">
import { useArticleStore } from '@/stores/article';
import { useBlockStore } from '@/stores/blocks';
import type { CreateArticle } from 'env';
import { computed } from 'vue';
import { ref } from 'vue';
import { useRoute } from 'vue-router';

const store = useArticleStore()
const route = useRoute()
const complete = ref(false)

const article = computed(() => {
    return store.get(route.params['id'])!
})

async function submitHandler(data: CreateArticle) {
    try {
        let success = await store.update(article.value.id, data);
        if (success) {
            const blockStore = useBlockStore()
            blockStore.blocks[0].data.text = data.name
            await blockStore.save(article.value.id)
        }
    } catch (err) {
        console.log(err)
    } finally {
        complete.value = false
    }
}

</script>

<template>
<div class="article-editor">
    <h1>Change Article</h1>
    <FormKit type="form" style="width: 100%;" @submit="submitHandler">
        <FormKit type="text" name="name" id="name" validation="required" label="Name" placeholder="Article Name" :value="article.name" />
        <FormKit type="textarea" rows="10" name="description" id="description" validation="required" label="Description"
            :value="article.description" />
        <FormKit type="file" accept=".png, .jpg, .jpeg" file-item-icon="fileImage" no-files-icon="fileImage"
        label="Thumbnail" name="thumbnail" help="Add a thumnbnail image" />
    </FormKit>
</div>
</template>

<style lang="scss" scoped>

.article-editor {
    max-width: 25em;
    width: calc(100vw - 300px - 1000px);
    background-color: white;
    border-left: 1px solid var(--border-color);
    padding: 20px;
    display: grid;
    row-gap: 20px;
    justify-items: center;
    grid-auto-rows: max-content;
}

</style>