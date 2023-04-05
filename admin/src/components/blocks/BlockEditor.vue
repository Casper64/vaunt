<script setup lang="ts">
import { useBlockStore } from '@/stores/blocks';
import { ref } from 'vue';
import { useRoute } from 'vue-router';

const store = useBlockStore()
const route = useRoute()
const complete = ref(false)


</script>

<template>
<div class="block-editor">

</div>
</template>

<style lang="scss" scoped>

.block-editor {
    background-color: white;
    border-left: 1px solid var(--border-color);
}

</style>