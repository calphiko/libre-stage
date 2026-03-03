import { writable, derived } from 'svelte/store';
import { browser } from '$app/environment';

const defaultTheme = browser ? localStorage.getItem('selectedTheme') || 'wintry' : 'wintry';
const defaultMode = browser ? localStorage.getItem('colorMode') || 'auto' : 'auto';

export const currentTheme = writable(defaultTheme);
export const colorMode = writable(defaultMode);

// Reaktiver isDarkMode Store, der von eCharts und anderen Komponenten genutzt werden kann
export const isDarkMode = writable(browser ? document.documentElement.classList.contains('dark') : false);

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

    let dark;
    if (mode === 'auto') {
        dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    } else {
        dark = mode === 'dark';
    }
    document.documentElement.classList.toggle('dark', dark);

    // Update isDarkMode Store
    isDarkMode.set(dark);
}

// System Dark Mode Listener
if (browser) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
        if (localStorage.getItem('colorMode') === 'auto') {
            applyTheme();
        }
    });

    // Sofort beim Laden anwenden
    applyTheme();
}

// Skeleton 4 available themes
export const availableThemes = [
    { value: 'sahara', label: 'Sahara'},
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
