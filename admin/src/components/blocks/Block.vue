<script setup lang="ts">
import { useBlockStore } from '@/stores/blocks';
import type { OutputBlockData } from '@editorjs/editorjs';
import { capitalize } from 'vue';
import { computed } from 'vue';
const store = useBlockStore()

const props = defineProps<{
    block: OutputBlockData<string, any>,
    active: boolean
}>()

const icon = computed(() => {
    if (props.block.type == 'heading') {
        return `/admin/svg/h${props.block.data.level}.svg`
    }
    let blockIndex = store.names.indexOf(props.block.type)
    return `/admin/svg/${store.icons[blockIndex]}.svg`
})

const name = computed(() => {
    let name = capitalize(props.block.type)
    if (name == 'LinkTool') {
        name = 'Link'
    }
    return name
})

</script>

<template>
<div class="block" :class="{active}">
    <div class="block-icon">
        <img class="block-icon" :src="icon">
    </div>
    <p class="block-name">{{ name }}</p>
</div>
</template>

<style lang="scss" scoped>

.block {
    height: 40px;
    display: grid;
    padding-left: 20px;
    grid-template-columns: 30px 1fr;
    font-size: 16px;
    line-height: 40px;
    column-gap: 10px;
    transition: background-color .2s ease;
    cursor: pointer;

    &.active {
        background-color: var(--primary-light);
        border-left: 4px solid var(--primary);
        padding-left: 16px;
    }

    &:hover {
        background-color: var(--primary-light);
    }

    .block-icon {
        height: 35px;
    }
}

</style>