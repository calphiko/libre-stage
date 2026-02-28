import { writable } from 'svelte/store';

const toastStore = writable([]);

export function showError(message, autohide = 5000) {
    const id = Date.now() + Math.random();
    toastStore.update(queue => [...queue, {
        id,
        message,
        background: 'variant-filled-error',
        autohide: true,
        timeout: autohide
    }]);
}

export function showSuccess(message, autohide = 3000) {
    const id = Date.now() + Math.random();
    toastStore.update(queue => [...queue, {
        id,
        message,
        background: 'variant-filled-success',
        autohide: true,
        timeout: autohide
    }]);
}

export function showWarning(message, autohide = 4000) {
    const id = Date.now() + Math.random();
    toastStore.update(queue => [...queue, {
        id,
        message,
        background: 'variant-filled-warning',
        autohide: true,
        timeout: autohide
    }]);
}

export { toastStore };
