export const THEME_STORAGE_KEY = "phx:theme"
export const THEME_COOKIE = "jido_appearance"
export const RESOLVED_THEME_COOKIE = "jido_resolved_theme"
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

const writeCookie = (name, value) => {
  if (typeof document === "undefined") return
  const secure = globalThis.location?.protocol === "https:" ? "; Secure" : ""
  document.cookie = `${name}=${value}; Path=/; Max-Age=31536000; SameSite=Lax${secure}`
}

const resolvedTheme = (theme, prefersDark) =>
  theme === "system" ? (prefersDark ? "dark" : "light") : theme

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

  const resolved = resolvedTheme(theme, prefersDark)
  root.setAttribute("data-appearance", theme)
  root.setAttribute("data-theme", resolved)
  root.setAttribute("data-shadcn-theme", resolved)

  if (persist) writeStorage(storage, theme)
  writeCookie(THEME_COOKIE, theme)
  writeCookie(RESOLVED_THEME_COOKIE, resolved)
  syncThemeControls(theme, root)
  return theme
}

export const initializeTheme = (options = {}) => {
  const root = options.root ?? browserRoot()
  const storage = options.storage ?? browserStorage()
  const serverTheme = normalizeTheme(root?.getAttribute("data-appearance"))
  const storedTheme = readStorage(storage)
  const requestedTheme = serverTheme === "system" && storedTheme ? storedTheme : serverTheme
  return applyTheme(requestedTheme, {root, storage, persist: true})
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

  window.addEventListener("click", event => {
    const control = event.target?.closest?.("[data-theme-choice]")
    if (control) applyTheme(control.dataset.phxTheme)
  })

  window.addEventListener("phx:page-loading-stop", () => {
    const root = browserRoot()
    syncThemeControls(root?.getAttribute("data-appearance") ?? "system", root)
  })
}
