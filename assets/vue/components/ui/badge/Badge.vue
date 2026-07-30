<script setup lang="ts">
import {computed} from "vue"
import {cn} from "@/vue/lib/utils"

const props = withDefaults(defineProps<{
  variant?: "default" | "secondary" | "outline" | "healthy" | "attention"
  class?: string
}>(), {
  variant: "default",
  class: "",
})

const classes = computed(() => cn(
  "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors",
  {
    "border-transparent bg-primary text-primary-foreground": props.variant === "default",
    "border-transparent bg-secondary text-secondary-foreground": props.variant === "secondary",
    "border-border text-foreground": props.variant === "outline",
    "border-transparent bg-status-healthy/15 text-status-healthy": props.variant === "healthy",
    "border-transparent bg-status-attention/15 text-status-attention": props.variant === "attention",
  },
  props.class,
))
</script>

<template>
  <span :class="classes">
    <slot />
  </span>
</template>
