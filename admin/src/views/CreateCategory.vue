<script setup lang="ts">
import { ref } from 'vue'
import { FormKit } from '@formkit/vue'
import { useRouter } from 'vue-router';
import { userCategoryStore } from '@/stores/category';

const categoryStore = userCategoryStore()
const router = useRouter()

const errorMessage = ref('')
const complete = ref(false)

const submitHandler = async (data: any) => {
    errorMessage.value = ''

    try {
        await categoryStore.create(data)
        router.push(`/admin/`)
    } catch (err: any) {
        errorMessage.value = err.response.data
    } finally {
        complete.value = true
    }
}

</script>

<template>
    <div class="creator">
        <h1>Create Category</h1>
        <!-- 25em is the default max width of FormKit -->
        <FormKit 
            type="form"
            style="width: 25em;"
            @submit="submitHandler"
        >
            <FormKit 
                type="text" 
                name="name" 
                id="name" 
                validation="required"
                label="Name" 
                placeholder="Category Name" 
            />
            <p v-if="errorMessage" class="error">{{ errorMessage }}</p>
        </FormKit>
    </div>
</template>

<style lang="scss" scoped>
.creator {
    display: grid;
    height: calc(100vh - 80px);
    align-content: center;
    justify-items: center;
    row-gap: 50px;
}
</style>