<script setup lang="ts">
import {computed} from "vue"
import {Badge} from "@/vue/components/ui/badge"
import {Button} from "@/vue/components/ui/button"

interface RuntimeEvent {
  id: string
  message: string
  at: string
}

interface RuntimeSemanticEvent {
  action: "ping" | "reset"
}

const props = withDefaults(defineProps<{
  connected?: boolean
  heartbeatCount?: number
  startedAt?: string
  events?: RuntimeEvent[]
}>(), {
  connected: false,
  heartbeatCount: 0,
  startedAt: "",
  events: () => [],
})

const emit = defineEmits<{
  (event: "semantic-event", payload: RuntimeSemanticEvent): void
}>()

const statusLabel = computed(() => props.connected ? "Connected" : "Starting")
const statusVariant = computed(() => props.connected ? "healthy" : "attention")

function sendPing() {
  emit("semantic-event", {action: "ping"})
}

function resetCounter() {
  emit("semantic-event", {action: "reset"})
}
</script>

<template>
  <section
    id="runtime-status-island-root"
    class="grid h-full min-h-0 gap-4 text-foreground"
    aria-labelledby="runtime-status-island-title"
    :data-connected="connected ? 'true' : 'false'"
  >
    <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <p class="text-sm font-medium text-muted-foreground">LiveVue island</p>
        <h2 id="runtime-status-island-title" class="mt-1 text-lg font-semibold">
          Runtime control
        </h2>
      </div>
      <Badge :variant="statusVariant">
        {{ statusLabel }}
      </Badge>
    </div>

    <div class="grid gap-3 sm:grid-cols-2">
      <div class="rounded-md border border-border bg-card p-4 text-card-foreground">
        <p class="text-sm text-muted-foreground">Heartbeats</p>
        <p class="mt-2 text-4xl font-semibold tracking-tight">{{ heartbeatCount }}</p>
      </div>

      <div class="rounded-md border border-border bg-card p-4 text-card-foreground">
        <p class="text-sm text-muted-foreground">Started</p>
        <p class="mt-2 font-mono text-sm">{{ startedAt || "pending" }}</p>
      </div>
    </div>

    <div class="flex flex-wrap gap-2">
      <Button type="button" size="sm" @click="sendPing">
        Ping
      </Button>
      <Button type="button" variant="outline" size="sm" @click="resetCounter">
        Reset
      </Button>
    </div>

    <div class="min-h-0 rounded-md border border-border bg-background">
      <div class="border-b border-border px-3 py-2">
        <p class="text-sm font-medium">Recent events</p>
      </div>
      <ol class="max-h-44 overflow-auto p-3 text-sm">
        <li v-if="events.length === 0" class="text-muted-foreground">
          No events yet.
        </li>
        <li
          v-for="event in events"
          :id="`runtime-island-event-${event.id}`"
          :key="event.id"
          class="flex items-center justify-between gap-3 border-b border-border py-2 last:border-b-0"
        >
          <span>{{ event.message }}</span>
          <time class="font-mono text-xs text-muted-foreground" :datetime="event.at">
            {{ event.at }}
          </time>
        </li>
      </ol>
    </div>
  </section>
</template>
