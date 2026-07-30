<script setup lang="ts">
import {computed} from "vue"
import {cn} from "@/vue/lib/utils"

const props = withDefaults(defineProps<{
  type?: "button" | "submit" | "reset"
  variant?: "default" | "secondary" | "outline" | "ghost"
  size?: "default" | "sm" | "icon"
  class?: string
}>(), {
  type: "button",
  variant: "default",
  size: "default",
  class: "",
})

const classes = computed(() => cn(
  "inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50",
  {
    "bg-primary text-primary-foreground hover:bg-primary/90": props.variant === "default",
    "bg-secondary text-secondary-foreground hover:bg-secondary/80": props.variant === "secondary",
    "border border-border bg-background hover:bg-accent hover:text-accent-foreground": props.variant === "outline",
    "hover:bg-accent hover:text-accent-foreground": props.variant === "ghost",
    "h-10 px-4 py-2": props.size === "default",
    "h-8 px-3 text-xs": props.size === "sm",
    "size-9": props.size === "icon",
  },
  props.class,
))
</script>

<template>
  <button :type="type" :class="classes">
    <slot />
  </button>
</template>
