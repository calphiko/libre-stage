import { writable } from 'svelte/store';


function createPersistentStore(key, initial) {
  const stored = localStorage.getItem(key);
  const store = writable(stored ? JSON.parse(stored) : initial);

  store.subscribe(value => {
    localStorage.setItem(key, JSON.stringify(value));
  });

  return store;
}

export const gigIdForEditor = createPersistentStore('gigIdForEditor', 0); //
//export const gigIdForEditor = writable(0);