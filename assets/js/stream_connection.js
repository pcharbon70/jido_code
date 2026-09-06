import {action, actions} from "../vendor/datastar/datastar.js"
import {clearProtectedContent, readInFlight, remember, restore} from "./read_projection.js"

// Transport correlation only. Identity, scope and revisions stay on the server.
const randomId = () => btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(16))))
  .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")
// Scoped to this loaded page, stable across retries, never persisted on reload.
const tabId = randomId()
const queryKeys = new Set(["q", "state", "sort", "direction", "page"])
const terminalStatuses = new Set([401, 403, 404, 409, 422, 429, 503])
const attemptOrigins = new WeakSet()
const maxLifetimeMs = 30_000
let active = null

const status = text => {
  const node = document.getElementById("product-stream-status")
  if (node) node.textContent = text
}

const stop = (session, clear = false) => {
  if (!session || active !== session) return
  active = null
  clearTimeout(session.deadlineTimer)
  session.cancel.abort()
  session.attempt?.controller.abort()
  if (clear) {
    const saved = remember()
    clearProtectedContent(true)
    restore(saved)
  }
}

const pause = (milliseconds, signal) => new Promise(resolve => {
  if (signal.aborted) return resolve()
  const done = () => {
    clearTimeout(timer)
    signal.removeEventListener("abort", done)
    resolve()
  }
  const timer = setTimeout(done, milliseconds)
  signal.addEventListener("abort", done, {once: true})
})

// A distinct, detached event origin per attempt prevents already-buffered old
// chunks from reaching Datastar's patch watcher after cancellation/takeover.
// It is never a rendered fragment, an expression source, or an authority source.
document.addEventListener("datastar-fetch", event => {
  const {el, type, argsRaw} = event.detail
  if (!attemptOrigins.has(el)) return
  const session = active
  const attempt = session?.attempt
  if (!attempt || attempt.el !== el || attempt.controller.signal.aborted) {
    event.stopImmediatePropagation()
    return
  }
  if (type === "error") {
    attempt.failedStatus = Number(argsRaw?.status) || 0
    if (terminalStatuses.has(attempt.failedStatus)) stop(session, true)
  }
  if (type !== "datastar-patch-elements") return
  if (attempt.failedStatus !== null || Date.now() >= session.deadline) {
    event.stopImmediatePropagation()
    if (Date.now() >= session.deadline) stop(session, true)
    return
  }
  const saved = remember()
  queueMicrotask(() => {
    if (active !== session || session.attempt !== attempt) return
    const terminal = document.querySelector("#product-shell[data-stream-terminal]")
    if (terminal) {
      stop(session)
      document.getElementById("product-stream-status")?.focus({preventScroll: true})
      return
    }
    const cursor = document.getElementById("product-owned-content")?.dataset.streamCursor
    if (cursor) {
      session.cursor = cursor
      status("Connected. Access is checked regularly; use refresh for newer data.")
    }
    restore(saved)
  })
}, true)

const run = async (context, controls) => {
  stop(active)
  const session = {cancel: new AbortController(), attempt: null, cursor: null, deadline: Date.now() + maxLifetimeMs}
  active = session
  session.deadlineTimer = setTimeout(() => stop(session, true), maxLifetimeMs)
  const query = Object.fromEntries([...new URL(location.href).searchParams].filter(([key]) => queryKeys.has(key)))

  // Three total attempts: initial connect, then at most two transient retries.
  for (let retry = 0; retry <= 2 && active === session; retry++) {
    if (retry > 0) {
      clearProtectedContent()
      status("Connection interrupted. Retrying with a fresh access check…")
      await pause(retry * 1_000, session.cancel.signal)
    }
    if (active !== session || Date.now() >= session.deadline || !controls.isConnected) break
    const el = document.createElement("span")
    attemptOrigins.add(el)
    const attempt = {el, controller: new AbortController(), failedStatus: null}
    session.attempt = attempt
    status(retry ? "Reconnecting…" : "Connecting…")
    const correlation = {tab: tabId, request: randomId()}
    if (session.cursor) correlation.cursor = session.cursor
    try {
      await actions.post({...context, el}, controls.dataset.streamEndpoint, {
        payload: {stream: correlation, [controls.dataset.streamNamespace]: query},
        headers: {"Accept": "text/event-stream", "x-csrf-token": document.querySelector("meta[name='csrf-token']").content},
        requestCancellation: attempt.controller,
        openWhenHidden: true,
        retry: "never",
        retryMaxCount: 0,
      })
    } catch {
      // Raw transport/SDK exceptions are never rendered into product content.
    }
    if (active !== session) return
    attempt.controller.abort()
    if (terminalStatuses.has(attempt.failedStatus)) break
  }
  if (active === session) {
    stop(session)
    clearProtectedContent()
    status("Not connected. Reload to check access and refresh this view.")
  }
}

action({
  name: "openStream",
  apply: async (context, event) => {
    if (event.type !== "click" || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    if (!event.target.closest("#product-stream-connect")) return
    event.preventDefault()
    if (readInFlight(context.el.closest("[data-read-endpoint]"))) {
      status("Connect again after this refresh finishes.")
      return
    }
    await run(context, context.el)
  },
})

document.addEventListener("product-read-intent", () => {
  if (!active) return
  stop(active)
  status("Connection paused for this refresh. Connect again to keep access checked.")
})
document.addEventListener("visibilitychange", () => {
  if (active && Date.now() >= active.deadline) stop(active, true)
})
window.addEventListener("offline", () => stop(active, true))
window.addEventListener("pagehide", () => stop(active, true))
window.addEventListener("pageshow", event => {
  if (event.persisted && document.getElementById("product-owned-content")) {
    stop(active, true)
    clearProtectedContent(true)
    location.reload()
  }
})
