<script setup lang="ts">
import { userCategoryStore } from '@/stores/category';
import { ref } from 'vue'

const categoryStore = userCategoryStore()

const complete = ref(false)

const submitHandler = async function(data: any, category_id: number) {
    try {
        await categoryStore.update(category_id, data)
    } catch(err) {}
    finally {
        complete.value = true
    }
}

async function deleteCategory(id: number) {
    if (window.confirm(`Are you sure you want to delete category "${categoryStore.get(id)?.name}"?`)) {
        try {
            await categoryStore.remove(id)
        } catch (err) {}
        finally {
            complete.value = true
        }
    }
}

</script>

<template>
    <div class="settings-container">
        <h1>Settings</h1>
        <div class="categories">
            <h2>Manage Categories</h2>
            <template v-for="category in categoryStore.categories">
                <div class="update-category">
                    <h3>{{  category.name }}</h3>
                    <FormKit 
                        type="form"
                        style="width: 25em;"
                        @submit="(data) => submitHandler(data, category.id)"
                        submit-label="Update"
                    >
                        <FormKit 
                            type="text" 
                            name="name" 
                            id="name" 
                            validation="required"
                            label="Name" 
                            placeholder="Category Name" 
                            :value="category.name"
                        />
                    </FormKit>
                    <FormKit outer-class="delete-btn" type="button" @click="() => deleteCategory(category.id)">Delete</FormKit>
                </div>
            </template>
        </div>
    </div>
</template>

<style lang="scss">

.delete-btn .formkit-input {
    background: red !important;
}

</style>