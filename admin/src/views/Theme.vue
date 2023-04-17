<script setup lang="ts">
import ColorPicker from '@/components/ColorPicker.vue';
import axios from '@/plugins/axios'
import { useThemeStore } from '@/stores/theme';
import { ref } from 'vue';

import 'alwan/dist/css/alwan.min.css'
import { watch } from 'vue';

const store = useThemeStore()
const complete = ref(false)

async function updateColors(data: any) {
    try {
        await axios.post('/theme/color', store.colors)
    } catch (err) {
        console.log(err)
    } finally {
        complete.value = false
    }
}

async function updateClassLists(data: any) {
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

watch(() => store.classLists, () => {
    selected.value = Object.keys(store.classLists).map(k => store.classLists[k].selected)
})

</script>

<template>
    <div class="theme-panel">
        <div class="colors">
            <h1>Colors</h1>
            <FormKit type="form" @submit="updateColors" submit-label="Save">
                <template v-for="color_name in Object.keys(store.colors)">
                    <ColorPicker :color_name="color_name" v-model="store.colors[color_name]" :label="nameLabel(color_name)"/>
                </template>
                <FormKit outer-class="reset-button" type="button" @click="store.fetchColors">Reset</FormKit>
            </FormKit> 
        </div>
        <div class="classlists">
            <h1>Style Configuration</h1>
            <FormKit type="form" @submit="updateClassLists" submit-label="Save">
                <template v-for="class_name, idx in Object.keys(store.classLists)">
                    <FormKit
                        type="radio" 
                        :name="class_name"
                        :label="store.classLists[class_name].name"
                        v-model="selected[idx]"
                        :options="store.classLists[class_name].options"
                    />
                </template>
                <FormKit outer-class="reset-button" type="button" @click="store.fetchClasslists">Reset</FormKit>
            </FormKit>
        </div>
    </div>
</template>

<style lang="scss" scoped>

.theme-panel {
    display: grid;
    grid-template-columns: 300px 1fr;
    column-gap: 50px;
    row-gap: 50px;
    padding: 50px;

    & > div h1 {
        margin-bottom: 20px;
    }
}

.colors, .classlists {
    display: grid;
    justify-items: center;
    row-gap: 10px;
    grid-template-rows: max-content 1fr;
}

.classlists h1 {
    text-align: left;
    width: 100%;
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
        grid-auto-rows: max-content;
        column-gap: 10px;
        row-gap: 10px;
        max-width: 300px;
        // grid-auto-flow: dense;

        .formkit-wrapper {
            justify-items: center;
        }

        label {
            text-align: center;
        }
    }

}

.theme-panel {
    .reset-button {
        margin-top: 20px;
        grid-column-start: 1;
    }

    .formkit-actions {
        grid-column-start: 3;
    }

    [data-type="button"] {
        width: 100%;
    }
}

.classlists {
    form.formkit-form {
        display: grid;
        justify-items: center;
        align-items: end;
        grid-template-columns: repeat(auto-fit, 250px);
        grid-auto-rows: max-content;
        column-gap: 10px;
        row-gap: 10px;
        // max-width: 300px;
        // grid-auto-flow: dense;

        .formkit-wrapper {
            justify-items: center;
        }

        label {
            text-align: center;
        }
    }
}



</style>