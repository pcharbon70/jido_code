<script setup lang="ts">
import {Badge} from "@/vue/components/ui/badge"

interface ToolchainEntry {
  id: string
  label: string
  status: string
  detail: string
}

withDefaults(defineProps<{
  entries?: ToolchainEntry[]
}>(), {
  entries: () => [],
})
</script>

<template>
  <section
    id="toolchain-status-island-root"
    class="grid gap-4 text-foreground"
    aria-labelledby="toolchain-status-island-title"
  >
    <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <p class="text-sm font-medium text-muted-foreground">Frontend island</p>
        <h2 id="toolchain-status-island-title" class="mt-1 text-lg font-semibold">
          Toolchain status
        </h2>
      </div>
      <Badge variant="secondary">Vite SSR</Badge>
    </div>

    <div class="grid gap-3 sm:grid-cols-2">
      <article
        v-for="entry in entries"
        :id="`toolchain-entry-${entry.id}`"
        :key="entry.id"
        class="rounded-md border border-border bg-card p-4 text-card-foreground"
      >
        <div class="flex items-start justify-between gap-3">
          <div>
            <h3 class="text-sm font-semibold">{{ entry.label }}</h3>
            <p class="mt-1 text-sm leading-5 text-muted-foreground">{{ entry.detail }}</p>
          </div>
          <Badge variant="healthy">{{ entry.status }}</Badge>
        </div>
      </article>
    </div>
  </section>
</template>
