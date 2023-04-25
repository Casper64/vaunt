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
                        @submit="(data) => submitHandler(data, category.id)"
                        submit-label="Change name"
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
            <router-link to="/admin/create-category" class="add-category-btn">
                <FormKit type="button" prefix-icon="add">Add Category</FormKit>
            </router-link>
        </div>
    </div>
</template>

<style scoped lang="scss">

.settings-container {
    max-width: 1100px;
    margin: auto;
    width: 100%;
    height: calc(100vh - 80px);
    display: grid;
    grid-template-rows: auto 1fr;
    justify-items: center;
    padding: 50px;
    row-gap: 20px;
}

.categories {
    width: 100%;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    grid-auto-rows: max-content;
    column-gap: 20px;
    row-gap: 20px;
    align-items: center;
    justify-items: center;

    & > h2 {
        grid-column: span 3;
    }

    .update-category {
        width: 250px;
    }
}

</style>

<style lang="scss">

.delete-btn .formkit-input {
    background: red !important;
}

</style>