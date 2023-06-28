<script setup lang="ts">
import { useBlockStore } from '@/stores/blocks';
import Block from '@/components/blocks/Block.vue'
import { onMounted, ref, onBeforeUnmount, computed } from 'vue';
import { blockComment } from '@codemirror/commands';

const store = useBlockStore()

const active = ref(0)

const headingBlocks = computed(() => {
    return store.blocks.filter(b => b.type == 'heading' && b.data.level <= 3)
})

const headingMap = computed(() => {
    const headerMap: Record<number, number> = {}
    let totalHeaders = 0
    store.blocks.forEach((b, index) => {
        if (b.type == 'heading' && b.data.level <= 3) {
            headerMap[index] = totalHeaders++
        } else {
            headerMap[index] = -1
        }
    })
    return headerMap
})

function checkActive() {
    const activeElement = document.querySelector('.ce-block--focused')!
    // check if block is a heading
    if (activeElement.children[0].children[0].classList.contains('ce-header') == false) {
        return
    }

    const parent = activeElement.parentNode!
    // get index amongst siblings to display a blue border around the focused block
    const index = Array.prototype.indexOf.call(parent.children, activeElement);
    active.value = headingMap.value[index]
}

function setActive(heading: number) {
    const index = Object.values(headingMap.value).indexOf(heading)
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

    active.value = heading
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
        <template v-for="block, index in headingBlocks">
            <Block :block="block" :active="active == index" @click="setActive(index)" />
        </template>
    </div>
</template>

<style lang="scss" scoped>

.block-container {
    height: calc(100vh - 80px - 64px);
    overflow-y: auto;
}

</style>