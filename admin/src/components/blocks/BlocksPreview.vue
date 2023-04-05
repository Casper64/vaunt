<script setup lang="ts">
import { createEditor } from '@/plugins/editor';
import { useBlockStore } from '@/stores/blocks';
import { onMounted } from 'vue';
import { ref } from 'vue';
import type EditorJS from '@editorjs/editorjs'
import type { EditorConfig } from '@editorjs/editorjs'
import { useRoute } from 'vue-router';

const store = useBlockStore()
const route = useRoute()

const editor = ref<EditorJS>()

const editorChange: EditorConfig['onChange'] = async (api, event) => {
    if (event.type == 'block-added' || event.type == 'block-removed' || event.type == 'block-changed') {
        const output = await editor.value?.save()
        if (output) {
            store.blocks = output.blocks;
            await store.save(route.params['id'])
        }
    }
} 

// TODO: add save callback

onMounted(() => {
    const server = import.meta.env.VITE_API_BASE_URL
    editor.value = createEditor('editor', store.blocks, {
        linkEndpoint: server+'fetch-link',
        uploadFile: server+'upload-image',
        uploadUrl: server+'upload-image-url'
    }, editorChange)

})


</script>

<template>
<div class="document">
    <div id="editor"></div>
    <!-- <div class="add-block">
        <FormKit type="button" prefix-icon="add" @click="popup = true">Add Block</FormKit>
    </div> -->
</div>
<!-- <Teleport to="body">
<div v-if="popup" class="popup-overlay" @click="popup = false">
    <div class="add-popup" @click.stop>
        <FormKit type="form" style="width: 25em;" @submit="addBlockHandler"> 
            <FormKit 
                type="select"
                label="New block type"
                name="block_type"
                :options="store.names"
            />
            <p v-if="errorMessage" class="error">{{ errorMessage  }}</p>
        </FormKit>
    </div>
</div>
</Teleport> -->
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

</style>

<style lang="scss">

.ce-block--focused {
    outline: 2px solid var(--primary);
}

</style>