<script setup lang="ts">
import { useBlockStore } from '@/stores/blocks';
import Block from '@/components/blocks/Block.vue'
import { onMounted, ref, onBeforeUnmount, computed } from 'vue';
import { blockComment } from '@codemirror/commands';

const store = useBlockStore()

const activeHeading = ref(0)
const current = ref(0)

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
    

    const parent = activeElement.parentNode!
    // get index amongst siblings to display a blue border around the focused block
    const index = Array.prototype.indexOf.call(parent.children, activeElement);

    current.value = index
    if (activeElement.children[0].children[0].classList.contains('ce-header') == true) {
        activeHeading.value = headingMap.value[index]
    } else {
        activeHeading.value = -1
    }
}

function setActive(index: number) {
    const editor = document.querySelector('.document-container')!
    const blocks = document.querySelectorAll('.ce-block')
    const activeElement = document.querySelector('.ce-block--focused')!
    if (activeElement) {
        activeElement.classList.remove('ce-block--focused')
    }
    
    const headingIndex = Object.values(headingMap.value).indexOf(index)
    if (headingIndex != -1) {

        blocks.item(headingIndex).classList.add('ce-block--focused')
        editor.scrollTo({
            behavior: 'smooth',
            //@ts-ignore
            top: blocks.item(headingIndex).offsetTop
        })

        activeHeading.value = index
        current.value = index
    }
    
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
    <p class="content">CURRENT BLOCK</p>
    <Block :block="store.blocks[current]" active @click="setActive(current)" />
    <p class="content">CONTENT</p>
    <div class="block-container">
        <template v-for="block, index in headingBlocks">
            <Block :block="block" :active="activeHeading == index" @click="setActive(index)" />
        </template>
    </div>
</template>

<style lang="scss" scoped>

.block-container {
    height: calc(100vh - 80px - 64px - 104px);
    overflow-y: auto;
}

p.content {
    color: var(--text);
    font-size: 20px;
    font-weight: 900;
    text-align: center;
    padding: 20px 0;
}

</style>