<!--
  libre-stage - Band rehearsal and gig management software
  Copyright (C) 2026  libre-stage contributors
  Admin page: Streaming platform management (Spotify / Tidal)
-->

<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { API_URL } from '$lib/api.js';
  import {
    getUser,
    getStreamingOAuthStatus,
    disconnectStreamingPlatform,
    triggerPlaylistSync,
    getPlaylistSyncLog,
  } from '$lib/api.js';
  import { toastState } from '$lib/toast.js';

  // ── new: credentials API ───────────────────────────────────────────────────
  async function fetchCredentials() {
    const res = await fetch(`${API_URL}/playlist/credentials`, { credentials: 'include' });
    if (!res.ok) throw new Error('Zugangsdaten konnten nicht geladen werden');
    return res.json();
  }

  async function saveCredentials(platform, data) {
    const res = await fetch(`${API_URL}/playlist/credentials/${platform}`, {
      method: 'PUT',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': getCsrfToken() },
      body: JSON.stringify(data),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail ?? 'Speichern fehlgeschlagen');
    }
    return res.json();
  }

  function getCsrfToken() {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; csrf_token=`);
    if (parts.length === 2) return parts.pop().split(';').shift() ?? '';
    return '';
  }
  // ── State ──────────────────────────────────────────────────────────────────
  let user = $state({ user_name: null, user_group: null });
  let oauthStatus = $state({ spotify: { connected: false }, tidal: { connected: false } });
  let syncLog = $state([]);
  let loading = $state(true);
  let syncing = $state(false);
  let showLog = $state(false);

  // Credential forms
  let spotifyForm = $state({ client_id: '', client_secret: '', playlist_id: '' });
  let tidalForm   = $state({ client_id: '', client_secret: '', playlist_id: '' });
  let spotifySecretSet = $state(false);
  let tidalSecretSet   = $state(false);
  let savingSpotify = $state(false);
  let savingTidal   = $state(false);

  // Success query params from OAuth callback
  let justConnected = $derived($page.url.searchParams.get('spotify') === 'connected'
    ? 'Spotify' : $page.url.searchParams.get('tidal') === 'connected'
    ? 'Tidal' : null);

  // ── Load ───────────────────────────────────────────────────────────────────
  async function loadData() {
    loading = true;
    try {
      [user, oauthStatus] = await Promise.all([
        getUser(),
        getStreamingOAuthStatus(),
      ]);
      if (user.user_group !== 'admin') {
        goto('/dashboard');
        return;
      }
      // Load stored credentials (without secrets)
      const creds = await fetchCredentials();
      spotifyForm.client_id    = creds.spotify?.client_id    ?? '';
      spotifyForm.playlist_id  = creds.spotify?.playlist_id  ?? '';
      spotifySecretSet          = creds.spotify?.client_secret_set ?? false;
      tidalForm.client_id      = creds.tidal?.client_id      ?? '';
      tidalForm.playlist_id    = creds.tidal?.playlist_id    ?? '';
      tidalSecretSet            = creds.tidal?.client_secret_set ?? false;
    } catch (e) {
      toastState.show(e.message, 'error');
    } finally {
      loading = false;
    }
  }

  async function saveSpotify() {
    savingSpotify = true;
    try {
      await saveCredentials('spotify', {
        client_id: spotifyForm.client_id,
        client_secret: spotifyForm.client_secret || undefined,
        playlist_id: spotifyForm.playlist_id,
      });
      spotifyForm.client_secret = '';
      toastState.show('Spotify-Zugangsdaten gespeichert ✓', 'success');
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    } finally {
      savingSpotify = false;
    }
  }

  async function saveTidal() {
    savingTidal = true;
    try {
      await saveCredentials('tidal', {
        client_id: tidalForm.client_id,
        client_secret: tidalForm.client_secret || undefined,
        playlist_id: tidalForm.playlist_id,
      });
      tidalForm.client_secret = '';
      toastState.show('Tidal-Zugangsdaten gespeichert ✓', 'success');
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    } finally {
      savingTidal = false;
    }
  }

  async function loadLog() {
    try {
      syncLog = await getPlaylistSyncLog();
    } catch (e) {
      toastState.show(e.message, 'error');
    }
  }

  onMount(async () => {
    await loadData();
    if (justConnected) {
      toastState.show(`${justConnected} erfolgreich verbunden ✓`, 'success');
    }
  });

  // ── Actions ────────────────────────────────────────────────────────────────
  function connectPlatform(platform) {
    // Navigate to backend OAuth endpoint (GET redirect)
    window.location.href = `${API_URL}/playlist/oauth/${platform}/connect`;
  }

  async function disconnectPlatform(platform) {
    if (!confirm(`${platform.charAt(0).toUpperCase() + platform.slice(1)} trennen?`)) return;
    try {
      await disconnectStreamingPlatform(platform);
      toastState.show(`${platform} getrennt`, 'success');
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    }
  }

  async function doSync() {
    syncing = true;
    try {
      const result = await triggerPlaylistSync();
      const parts = [];
      for (const [platform, r] of Object.entries(result)) {
        if (r.status === 'error') {
          parts.push(`${platform}: ❌ ${r.message}`);
        } else {
          parts.push(`${platform}: +${r.added || 0} / -${r.removed || 0}`);
        }
      }
      toastState.show(parts.join(' | ') || 'Sync abgeschlossen', 'success');
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    } finally {
      syncing = false;
    }
  }

  async function toggleLog() {
    showLog = !showLog;
    if (showLog && syncLog.length === 0) await loadLog();
  }

  function formatTs(ts) {
    if (!ts) return '–';
    try {
      return new Date(ts).toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' });
    } catch {
      return ts;
    }
  }
</script>

<svelte:head><title>Streaming-Einstellungen</title></svelte:head>

{#if loading}
  <div class="flex items-center justify-center h-40">
    <span class="text-surface-500">Laden…</span>
  </div>
{:else}

<div class="max-w-2xl mx-auto p-4 space-y-6">

  <div class="flex items-center gap-3">
    <button class="ui-btn ui-btn-ghost text-sm" onclick={() => goto('/admin/config')}>← Admin</button>
    <h1 class="text-xl font-bold">⚙ Streaming-Verbindungen</h1>
  </div>

  <!-- Config hint -->
  <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700 rounded-xl p-4 text-sm space-y-1">
    <p class="font-medium text-amber-800 dark:text-amber-300">ℹ Zugangsdaten werden verschlüsselt in der Datenbank gespeichert</p>
    <p class="text-amber-700 dark:text-amber-400">
      Trage unten Client-ID, Client-Secret und Playlist-ID ein.
      In <code class="bg-amber-100 dark:bg-amber-800 px-1 rounded">appConfig.json</code>
      musst du nur noch den <code class="bg-amber-100 dark:bg-amber-800 px-1 rounded">enabled</code>-Flag setzen.
    </p>
  </div>

  <!-- Spotify Card -->
  <div class="bg-surface-100 dark:bg-surface-800 rounded-xl p-5 space-y-4">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <span class="text-2xl">🎵</span>
        <div>
          <h2 class="font-semibold">Spotify</h2>
          <p class="text-xs text-surface-500">Authorization Code + PKCE</p>
        </div>
      </div>
      <span class="text-sm font-medium {oauthStatus.spotify?.connected ? 'text-green-500' : 'text-surface-400'}">
        {oauthStatus.spotify?.connected ? '✓ Verbunden' : '✗ Nicht verbunden'}
      </span>
    </div>

    <!-- Credential form -->
    <div class="space-y-2 border-t border-surface-200 dark:border-surface-700 pt-3">
      <p class="text-xs font-medium text-surface-500 uppercase tracking-wide">Zugangsdaten</p>
      <div class="grid grid-cols-1 gap-2">
        <div>
          <label class="text-xs text-surface-500">Client ID</label>
          <input class="ui-input w-full text-sm font-mono" bind:value={spotifyForm.client_id} placeholder="abc123def456..." />
        </div>
        <div>
          <label class="text-xs text-surface-500">
            Client Secret
            {#if spotifySecretSet}<span class="text-green-500">(gespeichert – leer lassen zum Behalten)</span>{/if}
          </label>
          <input class="ui-input w-full text-sm font-mono" type="password"
            bind:value={spotifyForm.client_secret}
            placeholder={spotifySecretSet ? '••••••••' : 'Nicht benötigt bei PKCE'} />
          <p class="text-xs text-surface-400 mt-0.5">Spotify PKCE benötigt kein Client Secret – Feld kann leer bleiben.</p>
        </div>
        <div>
          <label class="text-xs text-surface-500">Playlist-ID</label>
          <input class="ui-input w-full text-sm font-mono" bind:value={spotifyForm.playlist_id} placeholder="37i9dQZF1DX..." />
        </div>
      </div>
      <button class="ui-btn ui-btn-secondary text-sm" onclick={saveSpotify} disabled={savingSpotify || !spotifyForm.client_id}>
        {savingSpotify ? 'Speichern…' : '💾 Zugangsdaten speichern'}
      </button>
    </div>

    <!-- OAuth section -->
    {#if oauthStatus.spotify?.connected}
      <div class="text-xs text-surface-400 border-t border-surface-200 dark:border-surface-700 pt-3">
        Token gültig bis: {formatTs(oauthStatus.spotify.expires_at)}
        {#if oauthStatus.spotify.scope}<br>Scopes: <code>{oauthStatus.spotify.scope}</code>{/if}
      </div>
      <div class="flex gap-2">
        <button class="ui-btn ui-btn-secondary text-sm" onclick={() => connectPlatform('spotify')}>🔄 Neu verbinden</button>
        <button class="ui-btn ui-btn-ghost text-sm text-red-500" onclick={() => disconnectPlatform('spotify')}>Trennen</button>
      </div>
    {:else}
      <div class="border-t border-surface-200 dark:border-surface-700 pt-3">
        <button class="ui-btn ui-btn-primary text-sm" onclick={() => connectPlatform('spotify')}
          disabled={!spotifyForm.client_id}>
          Mit Spotify verbinden
        </button>
        {#if !spotifyForm.client_id}
          <p class="text-xs text-amber-500 mt-1">Erst Client-ID speichern</p>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Tidal Card -->
  <div class="bg-surface-100 dark:bg-surface-800 rounded-xl p-5 space-y-4">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <span class="text-2xl">🎶</span>
        <div>
          <h2 class="font-semibold">Tidal</h2>
          <p class="text-xs text-surface-500">Authorization Code + PKCE</p>
        </div>
      </div>
      <span class="text-sm font-medium {oauthStatus.tidal?.connected ? 'text-green-500' : 'text-surface-400'}">
        {oauthStatus.tidal?.connected ? '✓ Verbunden' : '✗ Nicht verbunden'}
      </span>
    </div>

    <!-- Credential form -->
    <div class="space-y-2 border-t border-surface-200 dark:border-surface-700 pt-3">
      <p class="text-xs font-medium text-surface-500 uppercase tracking-wide">Zugangsdaten</p>
      <div class="grid grid-cols-1 gap-2">
        <div>
          <label class="text-xs text-surface-500">Client ID</label>
          <input class="ui-input w-full text-sm font-mono" bind:value={tidalForm.client_id} placeholder="xyz789..." />
        </div>
        <div>
          <label class="text-xs text-surface-500">
            Client Secret
            {#if tidalSecretSet}<span class="text-green-500">(gespeichert – leer lassen zum Behalten)</span>{/if}
          </label>
          <input class="ui-input w-full text-sm font-mono" type="password"
            bind:value={tidalForm.client_secret}
            placeholder={tidalSecretSet ? '••••••••' : 'Client Secret eintragen'} />
        </div>
        <div>
          <label class="text-xs text-surface-500">Playlist-ID (UUID)</label>
          <input class="ui-input w-full text-sm font-mono" bind:value={tidalForm.playlist_id} placeholder="f0290623-5e50-..." />
        </div>
      </div>
      <button class="ui-btn ui-btn-secondary text-sm" onclick={saveTidal}
        disabled={savingTidal || !tidalForm.client_id}>
        {savingTidal ? 'Speichern…' : '💾 Zugangsdaten speichern'}
      </button>
    </div>

    <!-- OAuth section -->
    {#if oauthStatus.tidal?.connected}
      <div class="text-xs text-surface-400 border-t border-surface-200 dark:border-surface-700 pt-3">
        Token gültig bis: {formatTs(oauthStatus.tidal.expires_at)}
        {#if oauthStatus.tidal.scope}<br>Scopes: <code>{oauthStatus.tidal.scope}</code>{/if}
      </div>
      <div class="flex gap-2">
        <button class="ui-btn ui-btn-secondary text-sm" onclick={() => connectPlatform('tidal')}>🔄 Neu verbinden</button>
        <button class="ui-btn ui-btn-ghost text-sm text-red-500" onclick={() => disconnectPlatform('tidal')}>Trennen</button>
      </div>
    {:else}
      <div class="border-t border-surface-200 dark:border-surface-700 pt-3">
        <button class="ui-btn ui-btn-primary text-sm" onclick={() => connectPlatform('tidal')}
          disabled={!tidalForm.client_id}>
          Mit Tidal verbinden
        </button>
        {#if !tidalForm.client_id}
          <p class="text-xs text-amber-500 mt-1">Erst Client-ID speichern</p>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Manual sync -->
  <div class="bg-surface-100 dark:bg-surface-800 rounded-xl p-5 space-y-3">
    <h2 class="font-semibold">🔄 Manueller Sync</h2>
    <p class="text-sm text-surface-500">
      Vergleicht die interne Playlist (Songs mit ausreichender Bewertung) mit den remote Playlists
      und gleicht Hinzufügungen und Löschungen ab.
    </p>
    <button class="ui-btn ui-btn-primary text-sm" onclick={doSync} disabled={syncing}>
      {syncing ? 'Sync läuft…' : 'Jetzt synchronisieren'}
    </button>
  </div>

  <!-- Sync log -->
  <div>
    <button class="ui-btn ui-btn-ghost text-sm" onclick={toggleLog}>
      {showLog ? '▲ Sync-Log verbergen' : '▼ Sync-Log anzeigen'}
    </button>
    {#if showLog}
      <div class="mt-3 rounded-xl overflow-hidden border border-surface-200 dark:border-surface-700">
        {#if syncLog.length === 0}
          <p class="text-sm text-surface-400 p-4 text-center">Noch keine Einträge</p>
        {:else}
          <table class="w-full text-sm">
            <thead class="bg-surface-200 dark:bg-surface-700 text-left">
              <tr>
                <th class="px-3 py-2">Zeit</th>
                <th class="px-3 py-2">Plattform</th>
                <th class="px-3 py-2">Aktion</th>
                <th class="px-3 py-2">Fehler</th>
              </tr>
            </thead>
            <tbody>
              {#each syncLog as entry}
                <tr class="border-t border-surface-200 dark:border-surface-700 hover:bg-surface-100 dark:hover:bg-surface-800">
                  <td class="px-3 py-1.5 text-xs text-surface-500">{formatTs(entry.timestamp)}</td>
                  <td class="px-3 py-1.5">{entry.platform}</td>
                  <td class="px-3 py-1.5">{entry.action}</td>
                  <td class="px-3 py-1.5 text-red-500 text-xs">{entry.error_message ?? ''}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    {/if}
  </div>

</div>
{/if}







