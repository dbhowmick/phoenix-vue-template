<script setup lang="ts">
import { ref } from 'vue'

const count = ref(0)
</script>

<template>
  <main class="min-h-screen flex items-center justify-center p-8">
    <div class="max-w-xl text-center space-y-6">
      <h1 class="text-4xl font-semibold tracking-tight">Welcome to PhoenixVue</h1>
      <p class="text-base text-neutral-600 dark:text-neutral-400">
        Phoenix 1.8 + Vue 3 + Vite — wired up and ready. Edit
        <code class="font-mono text-sm rounded bg-neutral-100 dark:bg-neutral-800 px-1.5 py-0.5"
          >frontend/src/views/HomeView.vue</code
        >
        and save to see HMR in action.
      </p>
      <button
        class="rounded-md px-4 py-2 bg-neutral-900 text-white text-sm font-medium hover:bg-neutral-700 dark:bg-white dark:text-neutral-900 dark:hover:bg-neutral-200 transition-colors"
        @click="count++"
      >
        Clicked {{ count }} times
      </button>
      <div class="text-sm text-neutral-500">
        <a href="/dev/dashboard" class="underline hover:text-neutral-900 dark:hover:text-white">
          Phoenix LiveDashboard
        </a>
      </div>
    </div>
  </main>
</template>
