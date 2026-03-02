import { writable } from 'svelte/store';
import { browser } from '$app/environment';

const defaultTheme = browser ? localStorage.getItem('selectedTheme') || 'wintry' : 'wintry';
const defaultMode = browser ? localStorage.getItem('colorMode') || 'auto' : 'auto';

export const currentTheme = writable(defaultTheme);
export const colorMode = writable(defaultMode);

currentTheme.subscribe(value => {
    if (browser) {
        localStorage.setItem('selectedTheme', value);
        applyTheme();
    }
});

colorMode.subscribe(value => {
    if (browser) {
        localStorage.setItem('colorMode', value);
        applyTheme();
    }
});

function applyTheme() {
    if (!browser) return;

    const theme = localStorage.getItem('selectedTheme') || 'wintry';
    const mode = localStorage.getItem('colorMode') || 'auto';

    // Skeleton 4: data-theme on <html>
    document.documentElement.setAttribute('data-theme', theme);

    if (mode === 'auto') {
        const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        document.documentElement.classList.toggle('dark', isDark);
    } else {
        document.documentElement.classList.toggle('dark', mode === 'dark');
    }
}

// System Dark Mode Listener
if (browser) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
        if (localStorage.getItem('colorMode') === 'auto') {
            applyTheme();
        }
    });
}

// Skeleton 4 available themes
export const availableThemes = [
    { value: 'cerberus', label: 'Cerberus' },
    { value: 'catppuccin', label: 'Catppuccin' },
    { value: 'pine', label: 'Pine' },
    { value: 'rose', label: 'Rose' },
    { value: 'terminus', label: 'Terminus' },
    { value: 'vintage', label: 'Vintage' },
    { value: 'wintry', label: 'Wintry' }
];

export const colorModes = [
    { value: 'light', label: '☀️ Hell' },
    { value: 'dark', label: '🌙 Dunkel' },
    { value: 'auto', label: '⚙️ Auto' }
];
