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

    const theme = localStorage.getItem('selectedTheme') || 'modern';
    const mode = localStorage.getItem('colorMode') || 'auto';

    document.body.setAttribute('data-theme', theme);

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

export const availableThemes = [
    { value: 'skeleton', label: 'Skeleton' },
    { value: 'wintry', label: 'Wintry' },
    { value: 'modern', label: 'Modern' },
    { value: 'hamlindigo', label: 'Hamlindigo' },
    { value: 'rocket', label: 'Rocket' },
    { value: 'sahara', label: 'Sahara' },
    { value: 'gold-nouveau', label: 'Gold Nouveau' },
    { value: 'vintage', label: 'Vintage' },
    { value: 'seafoam', label: 'Seafoam' },
    { value: 'crimson', label: 'Crimson' }
];

export const colorModes = [
    { value: 'light', label: '☀️ Hell' },
    { value: 'dark', label: '🌙 Dunkel' },
    { value: 'auto', label: '⚙️ Auto' }
];
