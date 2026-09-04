export const THEME_STORAGE_KEY = "phx:theme"
export const THEMES = ["system", "light", "dark"]

export const normalizeTheme = theme => THEMES.includes(theme) ? theme : "system"

const browserRoot = () => typeof document === "undefined" ? null : document.documentElement
const browserStorage = () => typeof localStorage === "undefined" ? null : localStorage
const browserPrefersDark = () =>
  typeof window !== "undefined" && window.matchMedia?.("(prefers-color-scheme: dark)").matches

const readStorage = storage => {
  try {
    return storage?.getItem(THEME_STORAGE_KEY)
  } catch (_error) {
    return null
  }
}

const writeStorage = (storage, theme) => {
  if (!storage) return

  try {
    if (theme === "system") storage.removeItem(THEME_STORAGE_KEY)
    else storage.setItem(THEME_STORAGE_KEY, theme)
  } catch (_error) {
    // The document theme remains usable even if persistent storage is blocked.
  }
}

export const syncThemeControls = (theme, documentRoot = browserRoot()) => {
  const ownerDocument = documentRoot?.ownerDocument
  if (!ownerDocument) return

  ownerDocument.querySelectorAll("[data-phx-theme]").forEach(control => {
    control.setAttribute("aria-pressed", control.dataset.phxTheme === theme ? "true" : "false")
  })
}

export const applyTheme = (requestedTheme, options = {}) => {
  const theme = normalizeTheme(requestedTheme)
  const root = options.root ?? browserRoot()
  const storage = options.storage ?? browserStorage()
  const persist = options.persist ?? true
  const prefersDark = options.prefersDark ?? browserPrefersDark()

  if (!root) return theme

  root.setAttribute("data-appearance", theme)
  if (theme === "system") root.removeAttribute("data-theme")
  else root.setAttribute("data-theme", theme)
  root.setAttribute("data-shadcn-theme", theme === "system" ? (prefersDark ? "dark" : "light") : theme)

  if (persist) writeStorage(storage, theme)
  syncThemeControls(theme, root)
  return theme
}

export const initializeTheme = (options = {}) => {
  const root = options.root ?? browserRoot()
  const storage = options.storage ?? browserStorage()
  return applyTheme(readStorage(storage), {root, storage, persist: false})
}

export const bindThemeEvents = () => {
  if (typeof window === "undefined" || window.__jidoCodeThemeEventsBound) return
  window.__jidoCodeThemeEventsBound = true

  window.matchMedia?.("(prefers-color-scheme: dark)").addEventListener?.("change", event => {
    const root = browserRoot()

    if (root?.getAttribute("data-appearance") === "system") {
      applyTheme("system", {persist: false, prefersDark: event.matches})
    }
  })

  window.addEventListener("storage", event => {
    if (event.key === THEME_STORAGE_KEY) applyTheme(event.newValue, {persist: false})
  })

  window.addEventListener("phx:set-theme", event => {
    const control = event.target?.closest?.("[data-phx-theme]")
    if (control) applyTheme(control.dataset.phxTheme)
  })

  window.addEventListener("phx:page-loading-stop", () => {
    const root = browserRoot()
    syncThemeControls(root?.getAttribute("data-appearance") ?? "system", root)
  })
}
