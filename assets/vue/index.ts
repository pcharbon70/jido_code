import {h, type Component} from "vue"
import {
  createLiveVue,
  findComponent,
  type ComponentMap,
  type LiveHook,
} from "live_vue"
import HeartbeatStatusIsland from "./runtime/HeartbeatStatusIsland.vue"
import ToolchainStatusIsland from "./runtime/ToolchainStatusIsland.vue"
import FactoryFlowIsland from "./product/FactoryFlowIsland.vue"

declare module "vue" {
  interface ComponentCustomProperties {
    $live: LiveHook
  }
}

export const liveVueComponents = {
  "./runtime/HeartbeatStatusIsland.vue": HeartbeatStatusIsland,
  "./runtime/ToolchainStatusIsland.vue": ToolchainStatusIsland,
  "./product/FactoryFlowIsland.vue": FactoryFlowIsland,
} satisfies ComponentMap

export function resolveLiveVueComponent(name: string) {
  return findComponent(liveVueComponents, name)
}

export default createLiveVue({
  resolve: resolveLiveVueComponent,
  setup: ({createApp, component, props, slots, plugin, el}) => {
    const app = createApp({render: () => h(component as Component, props, slots)})

    app.use(plugin)
    app.mount(el)

    return app
  },
})
