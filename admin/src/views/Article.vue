<script setup lang="ts">
import ArticleEditor from '@/components/blocks/ArticleEditor.vue'
import ArticleThumbnail from '@/components/ArticleThumbnail.vue'
import ColorPicker from '@/components/ColorPicker.vue'
import TagComponent from '@/components/Tag.vue'
import { useRoute } from 'vue-router';
import { computed } from 'vue';
import { useArticleStore } from '@/stores/article';
import { ref } from 'vue';
import type { Tag } from 'env'
import { useTagStore } from '@/stores/tags';

const store = useArticleStore()
const tagStore = useTagStore()

const route = useRoute()
const article = computed(() => store.get(route.params.id)!)

const showAddTag = ref(false);
const showCreateTag = ref(false);

const newColor = ref('#000000');
const currentTagname = ref('');

const currentTags = computed(() => {
    return tagStore.tags.filter(x => x.article_id == article.value.id)
})

const baseTagsNames = computed(() => {
    return tagStore.baseTags().map(t => t.name)
})

const selectedTagsNames = computed(() => {
    let A = currentTags.value.map(x => x.name)
    let B = baseTagsNames.value

    // C = A subset B
    let intersect = A.filter(x => B.includes(x))
    return intersect
})

// AAAAAAAAA it won't work
// Why isn't it possible why??
// TODO: update store.tags in one time in `fetchData`
const selectedTags = computed(() => {
    let tags = selectedTagsNames.value
    return tags.map(x => tagStore.getBaseTag(x)!)
})

function updateTags(data: any) {
    let A: string[] = data['tags']
    let B = selectedTagsNames.value

    // A - B
    const addedTags = A.filter(x => !B.includes(x))
    // B - A
    const removedTags = B.filter(x => !A.includes(x))

    console.log(addedTags, removedTags)

    addedTags.forEach(name => {
        let tag = tagStore.getBaseTag(name)!
        tagStore.addToArticle(article.value.id, tag.id)
    })
    removedTags.forEach(name => {
        let tag = currentTags.value.find(x => x.name == name)!
        tagStore.deleteTag(tag.id, article.value.id)
    })
}

async function createTag(data: any) {
    if (data['tag_name'] == '') {
        showCreateTag.value = false;
        return
    }

    await tagStore.create(data['tag_name'], newColor.value, article.value.id)
    // currentTags.value.push(tagStore.tags[tagStore.tags.length - 1])

    newColor.value = '#000000'
    currentTagname.value = ''
    showCreateTag.value = false
}

</script>

<template>

<div class="article-settings">
    <div class="left">
        <ArticleThumbnail :article-id="article.id" :with-settings="true"/>
        <div class="tags">
            <div class="header">
                <h3>Tags</h3>
                <button @click="showAddTag = true">Change tags</button>
                <button @click="showCreateTag = true">Create tag</button>
            </div>
            <div class="add-tag" v-if="showAddTag">
                <FormKit type="form" @submit="updateTags" submit-label="Save">
                    <FormKit
                        :value="selectedTagsNames"
                        name="tags"
                        type="checkbox"
                        label="Tags"
                        :options="baseTagsNames"
                        />
                </FormKit>
            </div>
            <div class="new-tag" v-if="showCreateTag">
                <FormKit type="form" @submit="createTag" submit-label="Create tag">
                    <FormKit type="text" label="Tag name" name="tag_name" v-model="currentTagname"/>
                    <ColorPicker color_name="color" v-model="newColor" label=""/>
            </FormKit>
            </div>
            <div class="current-tags">
                <TagComponent v-for="tag in selectedTags" :tag="tag"/>
                <TagComponent v-if="currentTagname" :tag="{
                    id: 0,
                    article_id: 0,
                    name: currentTagname,
                    color: newColor
                }"/>
            </div>
        </div>
    </div>
    <div class="right">
        <ArticleEditor/>
    </div>
</div>

</template>

<style lang="scss" scoped>

.article-settings {
    display: grid;
    grid-template-columns: 1fr max-content;
    min-height: calc(100vh - 80px);
}

.left {
    padding: 50px;
    display: flex;
    justify-content: center;
    gap: 20px;
}

.right > * {
    height: 100%;
}

.tags {
    width: 400px;
    border: 1px solid var(--border-color);
    border-radius: 5px;
    background-color: white;
    padding: 20px;
    height: fit-content;
    display: flex;
    flex-direction: column;
    gap: 20px;
    min-height: 150px;
}

.tags .header {
    display: flex;

    h3 {
        flex-grow: 1;
    }

    button {
        color: var(--primary);
        cursor: pointer;
        padding: 4px 12px;
    }
}

.new-tag {
    display: grid;
    grid-template-columns: 1fr max-content;

    // bu
}

.current-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
}

</style>

<style lang="scss">

.new-tag .formkit-form {
    display: grid;
    grid-template-columns: 1fr max-content;
    align-items: center;
    column-gap: 20px;

    .formkit-actions {
        grid-column: span 2;
    }

    .color-picker {
        height: fit-content;
    }
}

</style>