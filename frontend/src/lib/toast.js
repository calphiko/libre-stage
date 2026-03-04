// src/lib/toast.js
// Simple reactive toast state for Skeleton 4 / Svelte 5

import { writable } from 'svelte/store';

const { subscribe, update } = writable([]);

export const toastState = {
  subscribe,
  add(toast) {
    const id = Date.now() + Math.random();
    const entry = { id, ...toast };
    update(queue => [...queue, entry]);

    if (toast.autohide !== false) {
      setTimeout(() => {
        toastState.remove(id);
      }, toast.timeout ?? 3000);
    }

    return id;
  },
  remove(id) {
    update(queue => queue.filter(t => t.id !== id));
  },
  clear() {
    update(() => []);
  }
};
