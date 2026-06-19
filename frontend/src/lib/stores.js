import { writable } from 'svelte/store';
import { browser } from '$app/environment';


function createPersistentStore(key, initial) {
  let initialValue = initial;
  if (browser) {
    try {
      const stored = localStorage.getItem(key);
      initialValue = stored ? JSON.parse(stored) : initial;
    } catch (_err) {
      initialValue = initial;
    }
  }

  const store = writable(initialValue);

  store.subscribe(value => {
    if (!browser) return;
    localStorage.setItem(key, JSON.stringify(value));
  });

  return store;
}

export const gigIdForEditor = createPersistentStore('gigIdForEditor', 0); //
//export const gigIdForEditor = writable(0);