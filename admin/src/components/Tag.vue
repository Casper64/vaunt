<script setup lang="ts">
import { useTagStore } from '@/stores/tags';
import type { Tag } from 'env';

const props = defineProps<{tag: Tag}>()
const store = useTagStore()

async function deleteBaseTag() {
    if (window.confirm('Do you want to delete this tag and remove it from all articles?')) {
        await store.deleteTag(props.tag.id)
    }
}

</script>

<template>
    <div class="tag" :style="{backgroundColor: tag.color}">
        <p>{{ tag.name }}</p>
        <img src="/admin/svg/delete.svg" @click="deleteBaseTag"/>
    </div>
</template>

<style lang="scss" scoped>

.tag {
    display: flex;
    flex-direction: row;
    align-items: flex-start;
    padding: 5px 25px;
    width: fit-content;
    border-radius: 15px;
    color: white;
    gap: 20px;
    padding-right: 10px;

    img {
        max-height: 20px;
        cursor: pointer;
    }
}

</style>