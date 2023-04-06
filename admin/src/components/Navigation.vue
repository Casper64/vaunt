<script setup lang="ts"></script>

<template>
    <nav>
        <a href="/" class="brand">V Blog</a>
        <div class="nav-links">
            <router-link to="/admin">Pages</router-link>
            <router-link to="/admin/stats">Statistics</router-link>
            <router-link to="/admin/settings">Settings</router-link>
        </div>
    </nav>
</template>