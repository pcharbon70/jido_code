const defaultSchedule = callback => window.requestAnimationFrame(callback)
const defaultCancel = handle => window.cancelAnimationFrame(handle)

export const createSaladUIHook = (
  baseHook,
  schedule = defaultSchedule,
  cancel = defaultCancel,
) => {
  const commandComponent = context => context.el?.dataset.component === "command"
  const commandReady = context => Boolean(
    context.el?.querySelector?.("[data-part='input']")
      && context.el?.querySelector?.("[data-part='list']"),
  )

  const scheduleCommandLifecycle = (context, method) => {
    if (context.saladUICommandMountFrame) cancel(context.saladUICommandMountFrame)

    context.saladUICommandMountFrame = schedule(() => {
      context.saladUICommandMountFrame = null
      if (!context.el?.isConnected) return
      if (!commandReady(context)) return scheduleCommandLifecycle(context, method)
      baseHook[method].call(context)
    })
  }

  return {
    ...baseHook,

    mounted() {
      if (commandComponent(this)) scheduleCommandLifecycle(this, "mounted")
      else baseHook.mounted.call(this)
    },

    updated() {
      if (commandComponent(this)) {
        scheduleCommandLifecycle(this, this.component ? "updated" : "mounted")
      } else {
        baseHook.updated.call(this)
      }
    },

    destroyed() {
      if (this.saladUICommandMountFrame) {
        cancel(this.saladUICommandMountFrame)
        this.saladUICommandMountFrame = null
      }

      if (this.component) baseHook.destroyed.call(this)
    },
  }
}
