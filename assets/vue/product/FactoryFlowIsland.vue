<script setup lang="ts">
import {computed, ref, watch} from "vue"
import {Badge} from "@/vue/components/ui/badge"
import {Button} from "@/vue/components/ui/button"

interface WorkflowStep {
  id: string
  label: string
  count: number
}

interface Workflow {
  revision?: number | null
  state: string
  selectedRepository?: string | null
  steps: WorkflowStep[]
}

const props = withDefaults(defineProps<{workflow?: Workflow}>(), {
  workflow: () => ({revision: null, state: "unavailable", selectedRepository: null, steps: []}),
})

const emit = defineEmits<{
  (event: "semantic-event", payload: {action: "refresh"} | {action: "select-surface", surface: string}): void
}>()

const selectedStep = ref<string | null>(null)
const sourceIdentity = computed(() => `${props.workflow.revision ?? "none"}:${props.workflow.selectedRepository ?? "fleet"}`)

watch(sourceIdentity, () => {
  selectedStep.value = null
})

function inspectStep(step: WorkflowStep) {
  selectedStep.value = step.id
  emit("semantic-event", {action: "select-surface", surface: step.id})
}
</script>

<template>
  <div id="factory-flow-island-root" class="grid gap-5" :data-source-identity="sourceIdentity">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <p class="text-xs font-medium uppercase text-muted-foreground">Graph-backed workflow</p>
        <h2 class="mt-1 text-lg font-semibold">Repository factory lifecycle</h2>
      </div>
      <div class="flex items-center gap-2">
        <Badge variant="outline">revision {{ workflow.revision ?? "-" }}</Badge>
        <Button type="button" variant="outline" size="sm" @click="emit('semantic-event', {action: 'refresh'})">
          Refresh
        </Button>
      </div>
    </div>

    <ol class="grid gap-2 md:grid-cols-5">
      <li v-for="(step, index) in workflow.steps" :key="step.id" class="min-w-0">
        <button
          :id="`factory-flow-${step.id}`"
          type="button"
          class="grid h-full min-h-24 w-full content-between rounded-md border border-border bg-card p-3 text-left text-card-foreground outline-none transition-colors hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring"
          :aria-pressed="selectedStep === step.id"
          @click="inspectStep(step)"
        >
          <span class="flex items-center justify-between gap-2">
            <span class="font-mono text-xs text-muted-foreground">{{ String(index + 1).padStart(2, "0") }}</span>
            <span class="inline-flex min-w-6 justify-center rounded bg-secondary px-1.5 text-xs font-semibold text-secondary-foreground">{{ step.count }}</span>
          </span>
          <span class="mt-4 truncate text-sm font-semibold">{{ step.label }}</span>
        </button>
      </li>
    </ol>

    <p class="text-xs text-muted-foreground">
      {{ workflow.selectedRepository ? "Repository-scoped projection" : "Factory-scoped projection" }} · {{ workflow.state }}
    </p>
  </div>
</template>
