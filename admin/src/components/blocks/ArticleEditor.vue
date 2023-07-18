<script setup lang="ts">
import { useArticleStore } from '@/stores/article';
import { useBlockStore } from '@/stores/blocks';
import type { CreateArticle } from 'env';
import { computed } from 'vue';
import { ref } from 'vue';
import { useRoute } from 'vue-router';
import { useCategoryStore } from '@/stores/category';
import { BASE_URL } from '@/plugins/urls';

const store = useArticleStore()
const categoryStore = useCategoryStore()
const route = useRoute()
const complete = ref(false)
const errorMessage = ref('')

const props = defineProps<{
    insideEditor?: boolean
}>();

const article = computed(() => {
    return store.get(route.params['id'])!
})
const currentCategory = ref(article.value.category_id)

const showStatus = ref(article.value.show ? 'Hide Article' : 'Show Article')

async function submitHandler(data: CreateArticle) {
    errorMessage.value = ''
    
    try {
        let success = await store.update(article.value.id, data)
        let new_article = store.get(article.value.id)!
        if (new_article.image_src) {
            // hardcoded for reactivity
            thumbnailSource.value = BASE_URL+new_article.image_src
        }

        if (success && props.insideEditor) {
            const blockStore = useBlockStore()
            
            // first block will never be changed since it contains the article name
            // so now we need to change it
            // blockStore.blocks[0].data.text = data.name
            await blockStore.save(article.value.id)
        }
    } catch (err: any) {
        errorMessage.value = err.response.data
    }
    finally {
        complete.value = false
    }
}

async function publishHandler() {
    try {
        await store.publish(article.value.id)
        showStatus.value = 'Hide Article'
    } catch (err) {}
    finally {
        complete.value = true
    }
}

async function changeVisibility() {
    try {
        await store.changeVisibility(article.value.id)
        // hardcoded for reactivity
        showStatus.value = showStatus.value == 'Show Article' ? 'Hide Article' : 'Show Article'
    } catch (err) {}
    finally {
        complete.value = true
    }
}

const thumbnailSource = ref(BASE_URL+article.value.image_src)

const categoryOptions = computed(() => {
    let obj: any = [{
        label: '[No Category]',
        value: 0
    }];
    categoryStore.categories.forEach(c => {
        obj.push({
            label: c.name,
            value: c.id
        })
    })
    return obj
})


</script>

<template>
<div class="article-editor">
    <h1>Change Article</h1>
    <FormKit type="form" @submit="submitHandler" submit-label="Update">
        <FormKit type="text" name="name" id="name" validation="required" label="Name" placeholder="Article Name" :value="article.name" />
        <FormKit
                type="select"
                label="Article Category"
                name="category_id"
                placeholder="Select a category (not required)"
                v-model="currentCategory"
                :options="categoryOptions"
            />
        <FormKit type="textarea" rows="10" name="description" id="description" validation="required" label="Description"
            :value="article.description" />

        <template v-if="article.thumbnail">
            <label class="formkit-label">Your current thumbnail</label>
            <img alt="your thumbnail" :src="thumbnailSource"/>
        </template>

        <FormKit type="file" accept=".png, .jpg, .jpeg" file-item-icon="fileImage" no-files-icon="fileImage"
        label="New thumbnail" name="thumbnail" help="Add a thumnbnail image"/>
    </FormKit>
    <p v-if="errorMessage" class="error">{{ errorMessage }}</p>
    <hr>
    <h1>Visibility</h1>
    <FormKit type="form" @submit="changeVisibility" :submit-label="showStatus"></FormKit> 
    <FormKit type="form" @submit="publishHandler" submit-label="Publish"></FormKit> 
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
    overflow-y: auto;

    hr {
        width: 100%;
        color: var(--text);
    }

    img {
        max-width: 100%;
        max-width: 300px;
    }
}

</style>