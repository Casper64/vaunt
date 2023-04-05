<script setup lang="ts">
import { useBlockStore } from '@/stores/blocks';
import Block from '@/components/blocks/Block.vue'
import { onMounted, ref } from 'vue';
import { onBeforeUnmount } from 'vue';

const store = useBlockStore()

const active = ref(0)

function checkActive() {
    const activeElement = document.querySelector('.ce-block--focused')!
    const parent = activeElement.parentNode!
    active.value = Array.prototype.indexOf.call(parent.children, activeElement);
}

function setActive(index: number) {
    const blocks = document.querySelectorAll('.ce-block')

    const activeElement = document.querySelector('.ce-block--focused')
    if (activeElement) {
        activeElement.classList.remove('ce-block--focused')
    }
    blocks.item(index).classList.add('ce-block--focused')
    const editor = document.querySelector('.document-container')!
    editor.scrollTo({
        behavior: 'smooth',
        //@ts-ignore
        top: blocks.item(index).offsetTop
    })

    active.value = index
}

onMounted(() => {
    const editor = document.getElementById('editor')!
    editor.addEventListener('click', checkActive)
})
onBeforeUnmount(() => {
    const editor = document.getElementById('editor')!
    editor.removeEventListener('click', checkActive)
})

</script>

<template>
    <div class="block-container">
        <template v-for="block, index in store.blocks">
            <Block :block="block" :active="active == index" @click="setActive(index)" />
        </template>
    </div>
</template>