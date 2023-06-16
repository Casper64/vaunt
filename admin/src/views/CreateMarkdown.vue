<script setup lang="ts">
import { ref } from 'vue'
import { FormKit } from '@formkit/vue'
import { useRouter } from 'vue-router';
import { useArticleStore } from '@/stores/article';
import { useCategoryStore } from '@/stores/category';
import { computed } from 'vue';

const articleStore = useArticleStore()
const categoryStore = useCategoryStore()
const router = useRouter()

const errorMessage = ref('')
const complete = ref(false)

const submitHandler = async (data: any) => {
    errorMessage.value = ''

    try {
        const insertedArticle = await articleStore.createWithMarkdown(data)
        router.push(`/admin/edit/${insertedArticle.id}`)
    } catch (err: any) {
        errorMessage.value = err.response.data
    } finally {
        complete.value = true
    }
}

const categoryOptions = computed(() => {
    let obj: any = [];
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
    <div class="create-article">
        <h1>Create Article</h1>
        <p>Note that not all markdown elements are supported!<br>Currently the following elements are supported:</p>
        <ul>
            <li>paragraphs</li>
            <li>h1-h3</li>
            <li>links, bold text</li>
            <li>images (the src and alt attributes will be copied)</li>
            <li>code blocks and inline code</li>
            <li>non-nested lists</li>
            <li>quotes</li>
            <li>tables</li>
        </ul>
        <!-- 25em is the default max width of FormKit -->
        <FormKit 
            type="form"
            style="width: 25em;"
            @submit="submitHandler"
        >
            <FormKit 
                type="file" 
                accept=".md, .txt" 
                file-item-icon="fileImage" 
                no-files-icon="fileImage"
                label="Markdown file" 
                name="markdown" 
                help="Add your markdown file"
                validation="required"
            />
            <FormKit 
                type="text" 
                name="name" 
                id="name" 
                validation="required"
                label="Name" 
                placeholder="Article Name" 
            />
            <FormKit 
                type="textarea" 
                rows="10" 
                name="description" 
                id="description" 
                validation="required" 
                label="Description"
                value="Short article description..." 
            />
            <FormKit 
                type="file" 
                accept=".png, .jpg, .jpeg" 
                file-item-icon="fileImage" 
                no-files-icon="fileImage"
                label="Thumbnail" 
                name="thumbnail" 
                help="Add a thumnbnail image"
            />
            <FormKit
                type="select"
                label="Article Category"
                name="category_id"
                placeholder="Select a category (not required)"
                :options="categoryOptions"
            />
            <p v-if="errorMessage" class="error">{{ errorMessage }}</p>
        </FormKit>
    </div>
</template>

<style lang="scss" scoped>
.create-article {
    display: grid;
    height: calc(100vh - 80px);
    align-content: center;
    justify-content: center;
    max-width: 500px;
    margin: auto;

    h1 {
        margin-bottom: 20px;
        text-align: center;
    }
}
</style>