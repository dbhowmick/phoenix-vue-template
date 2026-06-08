<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>

<template>
  <main class="min-h-screen flex items-center justify-center p-8">
    <div class="max-w-md text-center space-y-4">
      <p class="text-sm font-medium text-neutral-500">404</p>
      <h1 class="text-2xl font-semibold tracking-tight">Page not found</h1>
      <p class="text-base text-neutral-600 dark:text-neutral-400">
        The page you're looking for doesn't exist.
      </p>
      <RouterLink
        to="/"
        class="inline-block rounded-md px-4 py-2 bg-neutral-900 text-white text-sm font-medium hover:bg-neutral-700 dark:bg-white dark:text-neutral-900 dark:hover:bg-neutral-200 transition-colors"
      >
        Go home
      </RouterLink>
    </div>
  </main>
</template>
