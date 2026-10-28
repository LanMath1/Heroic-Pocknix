import { env } from 'process'
import { cpus } from 'os'
import { readFileSync } from 'graceful-fs'

interface Manifest {
  'runtime-version': string
}

function readFlatpakRuntimeVersion() {
  try {
    const manifestContent = readFileSync('/app/manifest.json', 'utf8')
    const manifest = JSON.parse(manifestContent) as Manifest
    return manifest['runtime-version']
  } catch (error) {
    console.log(
      `Unable to read runtime version from flatpak manifest file. ${error}`
    )
  }

  return 'unknown'
}

export const isMac = process.platform === 'darwin'
export const isIntelMac = isMac && cpus()[0].model.includes('Intel') // so we can have different behavior for Intel Mac
export const isWindows = process.platform === 'win32'
export const isLinux = process.platform === 'linux'

// --- Pocknix ---------------------------------------------------------------
// O AppImage roda com APPIMAGE_EXTRACT_AND_RUN=1 (não depende de FUSE) e
// alguns runtimes não propagam APPIMAGE para o processo, só ARGV0. Sem
// APPIMAGE, os atalhos gerados apontariam para "undefined". Recupera o
// caminho a partir do ARGV0.
if (!env.APPIMAGE) {
  const argv0 = env.ARGV0
  if (argv0 && argv0.toLowerCase().endsWith('.appimage')) {
    env.APPIMAGE = argv0
  }
}

// O atalho do launcher no Game Mode usa `--gamemode`, que é convenção do Steam
// Deck e não uma flag do Heroic. Traduz para `--fullscreen`, que é o que o
// AppRun do artefato de referência fazia.
if (process.argv.includes('--gamemode')) {
  process.argv = process.argv.filter((arg) => arg !== '--gamemode')
  process.argv.push('--fullscreen')
}
// ---------------------------------------------------------------------------

export const isSteamDeckGameMode =
  process.env.XDG_CURRENT_DESKTOP === 'gamescope'
const isSteamDeckDesktopMode =
  env.SESSION_MANAGER?.includes('unix/steamdeck') &&
  env.HOME === '/home/deck' &&
  env.DESKTOP_SESSION?.includes('steamos')
export const isSteamDeck = isSteamDeckGameMode || isSteamDeckDesktopMode
export const isCLIFullscreen = process.argv.includes('--fullscreen')
export const isCLINoGui = process.argv.includes('--no-gui')
export const isCLIConsoleMode = process.argv.includes('--console')
export const isFlatpak = Boolean(env.FLATPAK_ID)
export const isAppImage = Boolean(env.APPIMAGE)
export const flatpakRuntimeVersion = isFlatpak
  ? readFlatpakRuntimeVersion()
  : ''
export const autoUpdateSupported = isWindows || isMac || isAppImage
