import {action, actions} from "../vendor/datastar/datastar.js"

// Only explicit user gestures initiate a finite read. No subscriptions or retries.
// This state holds presentation intent, never identity, scope, grants or revisions.
const pending = new WeakMap()
const queryKeys = new Set(["q", "state", "sort", "direction", "page"])
let historyPath = location.pathname + location.search

const intent = (section, event) => {
  if (event.type === "submit") {
    const form = event.target
    if (!(form instanceof HTMLFormElement) || form.id !== "product-filter-search-form") return null
    return Object.fromEntries([...new FormData(form)].filter(([key]) => queryKeys.has(key)))
  }
  if (event.type !== "click" || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return null
  const link = event.target.closest("a[href]")
  if (!link || link.target || link.hasAttribute("download")) return null
  const url = new URL(link.href, location.href)
  if (url.origin !== location.origin || url.pathname !== section.dataset.readNative || url.hash) return null
  const pairs = [...url.searchParams]
  if (pairs.some(([key]) => !queryKeys.has(key)) || new Set(pairs.map(([key]) => key)).size !== pairs.length) return null
  return Object.fromEntries(pairs)
}

const clearProtectedContent = (terminal = false) => {
  const root = document.getElementById("product-owned-content")
  if (!root) return
  const status = document.createElement("p")
  status.id = "product-read-status"
  status.setAttribute("role", "alert")
  status.textContent = "This view could not be refreshed. Its earlier content has been cleared."
  const link = document.createElement("a")
  link.id = "product-read-reload"
  link.href = location.href
  link.textContent = "Reload the page"
  link.className = "underline underline-offset-4 focus-visible:outline-2"
  // Never retain hidden rows, templates, or old protected HTML after a failed read.
  root.replaceChildren(status, link)
  delete root.dataset.readUrl
  if (terminal) {
    // Lost/stale authority also invalidates the old scope/account/navigation shell.
    const shell = document.getElementById("product-shell")
    const main = document.createElement("main")
    main.id = "product-main"
    main.className = "mx-auto grid max-w-3xl gap-6 p-8"
    main.append(root)
    shell?.replaceChildren(main)
  }
}

const remember = () => {
  const focused = document.activeElement
  const selection = focused instanceof HTMLInputElement || focused instanceof HTMLTextAreaElement
    ? [focused.selectionStart, focused.selectionEnd, focused.selectionDirection] : null
  const formAction = focused?.closest("form")?.getAttribute("action")
  const opened = [...document.querySelectorAll("details[open][id], dialog[open][id]")]
    .map(node => ({node, modal: node instanceof HTMLDialogElement && node.matches(":modal")}))
  return {focused, selection, formAction, opened, x: scrollX, y: scrollY}
}

const restore = (saved) => {
  for (const {node, modal} of saved.opened) {
    // Restore only surviving elements; never resurrect removed protected content.
    if (node.isConnected && !node.open) {
      if (modal) node.showModal()
      else node.open = true
    }
  }
  const node = saved.focused
  if (node?.isConnected && node.closest("form")?.getAttribute("action") === saved.formAction) {
    node.focus({preventScroll: true})
    if (saved.selection?.[0] != null) node.setSelectionRange(...saved.selection)
  } else if (!node?.isConnected) {
    const status = document.getElementById("product-read-status")
    status?.setAttribute("tabindex", "-1")
    status?.focus({preventScroll: true})
  }
  window.scrollTo(saved.x, saved.y)
}

action({
  name: "readProjection",
  apply: async (context, event) => {
    const section = context.el
    const query = intent(section, event)
    if (query === null) return
    // Failed transport leaves an ordinary native reload link, without auto retry.
    if (event.target.closest?.("#product-read-reload")) return
    event.preventDefault()
    const previous = pending.get(section)
    previous?.abort()
    const controller = new AbortController()
    pending.set(section, controller)
    const formFields = [...section.querySelectorAll("#product-filter-search-form input[name='q'], #product-filter-search-form select[name='state']")]
      .map(node => ({node, value: node.value}))
    let saved = remember()
    const priorReceipt = document.getElementById("product-owned-content")?.dataset.readReceipt
    let failed = false
    let terminal = false
    const onFetch = ({detail}) => {
      if (detail.el !== section) return
      if (detail.type === "error") {
        failed = true
        terminal = [401, 403, 404, 409, 503].includes(Number(detail.argsRaw?.status))
      }
      if (detail.type === "datastar-patch-elements") saved = remember()
    }
    document.addEventListener("datastar-fetch", onFetch, true)
    section.setAttribute("aria-busy", "true")
    const timeout = setTimeout(() => {
      if (pending.get(section) === controller) {
        const current = remember()
        clearProtectedContent()
        restore(current)
        controller.abort()
      }
    }, 20_000)
    try {
      await actions.post(context, section.dataset.readEndpoint, {
        payload: {[section.dataset.readNamespace]: query},
        headers: {"x-csrf-token": document.querySelector("meta[name='csrf-token']").content},
        requestCancellation: controller,
        retry: "never",
        retryMaxCount: 0,
      })
      if (controller.signal.aborted || pending.get(section) !== controller) return
      if (failed) {
        saved = remember()
        clearProtectedContent(terminal)
      }
      else {
        const root = document.getElementById("product-owned-content")
        const path = root?.dataset.readUrl
        if (path && root.dataset.readReceipt && root.dataset.readReceipt !== priorReceipt) {
          if (path !== location.pathname + location.search) history.pushState(null, "", path)
          historyPath = location.pathname + location.search
          const normalized = new URL(path, location.origin).searchParams
          for (const {node, value} of formFields) {
            if (node.isConnected && node.value === value) node.value = normalized.get(node.name) ?? (node.name === "state" ? "all" : "")
          }
          const canonical = document.querySelector("link[rel='canonical']")
          if (canonical) canonical.href = new URL(path, location.origin).href
        }
        else clearProtectedContent()
      }
      restore(saved)
    } catch {
      if (!controller.signal.aborted && pending.get(section) === controller) {
        const current = remember()
        clearProtectedContent()
        restore(current)
      }
    } finally {
      clearTimeout(timeout)
      document.removeEventListener("datastar-fetch", onFetch, true)
      if (pending.get(section) === controller) {
        pending.delete(section)
        section.removeAttribute("aria-busy")
      }
    }
  },
})

// Native navigation discards all ephemeral state. No authority or filters persist
// in browser storage; a history traversal obtains a newly authorized full page.
window.addEventListener("popstate", () => {
  const path = location.pathname + location.search
  // In-page anchors (especially the skip link) must retain native focus.
  if (path !== historyPath && document.querySelector("[data-read-endpoint]")) location.reload()
})
