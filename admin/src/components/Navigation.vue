<script setup lang="ts">
import { BASE_URL } from '@/plugins/urls';

</script>

<template>
    <nav>
        <a href="/" class="brand">Vaunt</a>
        <div class="nav-links">
            <!-- <router-link to="/admin">Categories</router-link> -->
            <router-link to="/admin/">Home</router-link>
            <router-link to="/admin/theme">Theme</router-link>
            <router-link to="/admin/settings">Settings</router-link>
            <a :href="`${BASE_URL}/auth/logout`">Logout</a>
        </div>
    </nav>
</template>