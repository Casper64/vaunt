<script setup lang="ts">
import axios from '@/plugins/axios'
import { useThemeStore } from '@/stores/theme';
import { ref } from 'vue';

const store = useThemeStore()
const complete = ref(false)

async function updateColors(data: any) {
    console.log(data, typeof data)
    Object.keys(data).forEach(key => {
        store.colors[key] = data[key]
    })

    try {
        await axios.post('/theme/color', store.colors)
    } catch (err) {
        console.log(err)
    } finally {
        complete.value = false
    }
}

async function updateClassLists(data: any) {
    console.log(data)
    Object.keys(data).forEach(key => {
        store.classLists[key].selected = data[key]
    })
    try {
        await axios.post('/theme/classlist', store.classLists)
    } catch (err) {
        console.log(err)
    } finally {
        complete.value = false
    }
}

function nameLabel(label: string) {
    return label.replaceAll('_', ' ')
}

const selected = ref(Object.keys(store.classLists).map(k => store.classLists[k].selected))

</script>

<template>
    <div class="theme-panel">
        <div class="colors">
            <h1>Colors</h1>
            <FormKit type="form" @submit="updateColors" submit-label="Save">
                <template v-for="color_name in Object.keys(store.colors)">
                    <FormKit
                        type="color" 
                        :name="color_name"
                        :value="store.colors[color_name]" 
                        :label="nameLabel(color_name)"
                    />
                </template>
            </FormKit> 
        </div>
        <div class="classlists">
            <h1>Style Configuration</h1>
            <FormKit type="form" @submit="updateClassLists" submit-label="Save">
                <template v-for="class_name, idx in Object.keys(store.classLists)">
                    <FormKit
                        type="select" 
                        :name="class_name"
                        :label="store.classLists[class_name].name"
                        v-model="selected[idx]"
                        :options="store.classLists[class_name].options"
                    />
                </template>
            </FormKit>
        </div>
    </div>
</template>

<style lang="scss" scoped>

.theme-panel {
    display: grid;
    grid-template-columns: 300px 1fr;
    padding: 50px;
}

.colors {
    display: grid;
    justify-items: center;
    row-gap: 10px;
}

</style>

<style lang="scss">

.colors {
    form.formkit-form {
        display: grid;
        justify-items: center;
        align-items: end;
        grid-template-columns: repeat(3, 90px);
        // grid-auto-flow: column;
        grid-auto-rows: auto;
        column-gap: 10px;
        max-width: 300px;
        // grid-auto-flow: dense;

        .formkit-wrapper {
            justify-items: center;
        }

        label {
            text-align: center;
        }
    }

    [data-type="color"] .formkit-inner {
        border-radius: 27px;
        width: 27px;
        height: 27px;
        overflow: hidden;
        box-shadow: none;
        border: 1px solid var(--border-color);
    }

    [data-type="color"] input[type="color"] {
        width: 30px;
        height: 30px;
    }

    .formkit-actions {
        grid-column: span 3;
        // grid-row-start: 1;
    }
}



</style>