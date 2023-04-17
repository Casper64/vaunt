<script setup lang="ts">
import { ref } from 'vue';
import { onMounted } from 'vue';
import Alwan from 'alwan';
import { useThemeStore } from '@/stores/theme';
import { watch } from 'vue';

const store = useThemeStore()

const props = defineProps<{
    color_name: string
    label: string
    modelValue: any
}>()
const emit = defineEmits(['update:modelValue'])
 
const picker = ref<Alwan>()

watch(store.swatches, () => {
    picker.value?.setOptions({
        swatches: store.swatches
    })
})

watch(() => props.modelValue, () => {
    picker.value?.setColor(props.modelValue)
})

onMounted(() => {
    picker.value = new Alwan(`#${props.color_name}`, {
        color: props.modelValue,
        opacity: false,
        swatches: store.swatches,
        classname: 'picker-item',
        margin: 12
    })

    picker.value.on('change', (ev) => {
        emit('update:modelValue', ev.hex())
        store.addSwatch(ev.hex())
    })
})

</script>

<template>
    <div class="color-picker">
        <p>{{ label }}</p>
        <div :id="color_name"></div>
    </div>
</template>

<style lang="scss" scoped>

.color-picker {
    text-align: center;
    font-weight: bold;
}

</style>

<style lang="scss">

.picker-item {
    width: 30px;
    height: 30px;
    border: 1px solid var(--border-color) !important;
}

</style>