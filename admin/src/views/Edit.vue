<script setup lang="ts">
import BlocksContainer from '@/components/blocks/BlocksContainer.vue'
import BlocksPreview from '@/components/blocks/BlocksPreview.vue'
import ArticleEditor from '@/components/blocks/ArticleEditor.vue'

</script>

<template>
<div class="editor-container">
    <div class="block-sidebar">
        <BlocksContainer/>
    </div>
    <div class="document-container">
        <BlocksPreview/>
        
    </div>
    <ArticleEditor inside-editor/>
</div>
</template>

<style lang="scss" scoped>

.editor-container {
    display: grid;
    grid-template-columns: 300px 1fr max-content;
    height: calc(100vh - 80px);
}

.block-sidebar {
    background-color: white;
    border-right: 1px solid var(--border-color);
}

.document-container {
    padding: 50px;
    padding-bottom: 0;
    display: grid;
    justify-content: center;
    overflow-y: auto;
}


</style>