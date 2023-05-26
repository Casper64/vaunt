<script setup lang="ts">
import { createEditor } from '@/plugins/editor';
import { useBlockStore } from '@/stores/blocks';
import { onMounted } from 'vue';
import { ref } from 'vue';
import type EditorJS from '@editorjs/editorjs'
import type { EditorConfig } from '@editorjs/editorjs'
import { useRoute } from 'vue-router';
import { BASE_API_URL, BASE_URL } from '@/plugins/urls';

const store = useBlockStore()
const route = useRoute()

const editor = ref<EditorJS>()

const editorChange: EditorConfig['onChange'] = async (api, event) => {
    if (event.type == 'block-removed') {
        const el = event.detail.target.holder
        const img = el.querySelector('img')
        if (img && img.src.startsWith(BASE_URL)) {
            // its an uploaded image.
            await store.removeImage(img.src)
        }
    }
    if (event.type == 'block-added' || event.type == 'block-removed' || event.type == 'block-changed') {
        const output = await editor.value?.save()
        if (output) {
            // first block is the title, so we don't want to edit it
            // output.blocks.splice(0, 0, store.blocks[0])
            
            store.blocks = output.blocks;
            await store.save(route.params['id'])
        }
    }
} 

// TODO: add save callback with $mitt or something
onMounted(() => {
    const server = BASE_API_URL
    editor.value = createEditor('editor', store.blocks, {
        linkEndpoint: server+'fetch-link',
        uploadFile: server+'upload-image',
        uploadUrl: server+'upload-image-url'
    }, editorChange)

})


</script>

<template>
<div class="document">
    <div id="editor">
        <!-- <h1>{{ store.blocks[0]?.data.text }}</h1> -->
    </div>
</div>
</template>

<style lang="scss" scoped>

.document {
    width: 900px;
    height: 100%;
    background-color: white;
    border: 1px solid var(--border-color);
    padding: 50px;
}

.add-block {
    width: 100%;
    display: grid;
    justify-content: center;
}

.add-popup {
    width: 600px;
    height: 300px;
    padding: 50px;
    border-radius: 10px;
    background-color: white;
    border: 1px solid var(--border-color);
}

#editor > h1:first-of-type {
    text-align: center;
    margin-bottom: 20px;
}

</style>

<style lang="scss">

.ce-block--focused {
    outline: 2px solid var(--primary);
}

</style>