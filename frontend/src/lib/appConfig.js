// src/lib/appConfig.js
// Zentrale Konfiguration – wird vom Backend über /public/app_config geladen.
// Nach npm build kann die Konfiguration über config/appConfig.json
// geändert werden, ohne neu zu bauen.

import { writable, get } from 'svelte/store';
import { getAppConfig, invalidateAppConfigCache } from '$lib/api.js';

/**
 * Svelte Store für die App-Konfiguration.
 * Wird initial mit null befüllt und nach loadAppConfig() mit den Daten vom Backend.
 */
export const appConfig = writable(null);

let _loaded = false;
let _loadPromise = null;

export function resetAppConfigStore() {
  _loaded = false;
  _loadPromise = null;
  appConfig.set(null);
  invalidateAppConfigCache();
}

/**
 * Lädt die App-Konfiguration vom Backend und setzt den Store.
 * Wird nur einmal ausgeführt (Singleton). Kann von mehreren Stellen aufgerufen werden.
 * @returns {Promise<object>} Die geladene Konfiguration
 */
export async function loadAppConfig(forceReload = false) {
  if (forceReload) {
    resetAppConfigStore();
  }

  if (_loaded) return get(appConfig);

  if (_loadPromise) return _loadPromise;

  _loadPromise = (async () => {
    try {
      const config = await getAppConfig();
      appConfig.set(config);
      _loaded = true;
      return config;
    } catch (e) {
      console.error('App-Konfiguration konnte nicht geladen werden:', e);
      throw e;
    }
  })();

  return _loadPromise;
}
