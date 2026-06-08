<!--
  libre-stage - Band rehearsal and gig management software
  Copyright (C) 2026  libre-stage contributors

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

<script>
  import { createEventDispatcher, onMount } from 'svelte';
  let {
    options = [],
    selected = $bindable([]),
    placeholder = 'Tippe und drücke Enter',
    name = 'choices'
  } = $props();
  const dispatch = createEventDispatcher();

  let input = $state('');
  let open = $state(false);
  let activeIndex = $state(-1);

  let available = $derived(options
    .filter(o => !selected.includes(o))
    .filter(o => o.toLowerCase().includes(input.trim().toLowerCase())));

  function addTag(value) {
  value = value?.trim();
  if (!value) return;

  // Nur Werte aus der options-Liste zulassen
  if (!options.includes(value)) {
    console.warn('Wert nicht in der Auswahlliste:', value);
    return;
  }

  if (!selected.includes(value)) {
    selected = [...selected, value];
    dispatch('change', { selected });
    console.log('Tag hinzugefügt:', value);
  }
  input = '';
  open = false;
}

  function removeTag(idx) {
    selected = selected.slice(0, idx).concat(selected.slice(idx + 1));
    dispatch('change', { selected });
  }

  function onKeyDown(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (open && activeIndex >= 0 && available[activeIndex]) {
        addTag(available[activeIndex]);
      } else {
        addTag(input);
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      open = true;
      activeIndex = Math.min(activeIndex + 1, available.length - 1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      activeIndex = Math.max(activeIndex - 1, 0);
    } else if (e.key === 'Escape') {
      open = false;
      activeIndex = -1;
    } else if (e.key === 'Backspace' && input === '') {
      // letztes Tag entfernen
      if (selected.length) removeTag(selected.length - 1);
    }
  }

  // Klick außerhalb schließt Vorschläge
  onMount(() => {
    const handler = e => {
      if (!e.target.closest('.tag-input')) {
        open = false;
        activeIndex = -1;
      }
    };
    document.addEventListener('click', handler);
    return () => document.removeEventListener('click', handler);
  });
</script>

<div class="tag-input" role="application">
  <ul class="tags" role="application">
    {#each selected as tag,idx}
      <span class="chip variant-filled">
        {tag}
        <button
          type="button"
          class="chip-close"
          onclick={() => removeTag(idx)}
          aria-label="Remove {tag}"
        >
            ✕
        </button>
      </span>
      {#if selected.indexOf(tag) < selected.length - 1}
        <span class="tag-separator">+</span>
      {/if}
    {/each}
  </ul>

  <input
    type="text"
    bind:value={input}
    placeholder={placeholder}
    oninput={() => { open = input.trim() !== ''; activeIndex = 0; }}
    onkeydown={onKeyDown}
    aria-autocomplete="list"
    aria-expanded={open}
    aria-controls="suggestions"
  />

  <!-- Vorschläge -->
  {#if open && available.length > 0}
    <div class="suggestions-wrap" role="presentation">
      <div class="suggestions-title">Vorschläge</div>
      <ul id="suggestions" class="suggestions" role="listbox">
        {#each available as item, idx}
          <li
            role="option"
            class:active={idx === activeIndex}
            aria-selected={idx === activeIndex}
            onmousedown={(e) => { e.preventDefault(); addTag(item); }}
          >
            {item}
          </li>
        {/each}
      </ul>
    </div>
  {/if}

  <!-- Für klassische Formulare: Hidden Input -->
  <input class="hidden-input" type="hidden" name={name} value={JSON.stringify(selected)} />
</div>


<style>
  .tag-input {
    border: 1px solid rgb(var(--color-surface-400));
    background: rgb(var(--color-surface-100));
    padding: 0.5rem;
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    align-items: center;
    position: relative;
    border-radius: var(--theme-rounded-base);
    transition: border-color 200ms;
    width: 95%;
  }

  .tag-input:focus-within {
    border-color: rgb(var(--color-primary-500));
    outline: 2px solid rgb(var(--color-primary-500) / 0.2);
  }

  .tags {
    display: flex;
    gap: 0.5rem;
    list-style: none;
    margin: 0;
    padding: 0;
    flex-wrap: wrap;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.375rem 0.375rem;
    font-size: 0.875rem;
    background: rgb(var(--color-primary-500));
    color: rgb(var(--color-surface-50));
    border-radius: var(--theme-rounded-token);
  }

  .chip-close {
    border: none;
    background: transparent;
    cursor: pointer;
    font-weight: bold;
    color: inherit;
    padding: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 1rem;
    height: 1rem;
    opacity: 0.7;
    transition: opacity 200ms;
  }

  .chip-close:hover {
    opacity: 1;
  }

  input[type="text"] {
    border: none;
    outline: none;
    flex: 1;
    min-width: 120px;
    padding: 0.0rem;
    background: transparent;
    color: rgb(var(--color-surface-900));
    font-size: 0.875rem;
  }

  .suggestions-wrap {
    position: absolute;
    top: calc(100% + 0.35rem);
    left: 0;
    right: 0;
    z-index: 20;
    border: 2px solid rgb(var(--color-primary-500));
    border-radius: var(--theme-rounded-base);
    overflow: hidden;
    box-shadow: 0 14px 36px rgb(0 0 0 / 0.22);
    background-color: rgba(255, 255, 255, 0.98);
  }

  .suggestions-title {
    padding: 0.45rem 0.8rem;
    font-size: 0.72rem;
    letter-spacing: 0.05em;
    font-weight: 700;
    text-transform: uppercase;
    color: rgb(var(--color-primary-700));
    background: rgb(var(--color-primary-100));
    border-bottom: 1px solid rgb(var(--color-primary-300));
  }

  .suggestions {
    list-style: none;
    padding: 0.25rem;
    margin: 0;
    max-height: 220px;
    overflow-y: auto;
    background-color: rgba(250, 250, 250, 0.98);
  }

  .suggestions li {
    padding: 0.6rem 0.8rem;
    border-radius: 0.5rem;
    cursor: pointer;
    font-size: 0.9rem;
    color: rgb(var(--color-surface-900));
    transition: background-color 120ms, color 120ms, transform 120ms;
  }

  .suggestions li.active,
  .suggestions li:hover {
    background: rgb(var(--color-primary-500));
    color: rgb(var(--color-surface-50));
    transform: translateX(2px);
  }

  .tag-separator {
    margin: 0 0.25rem;
    color: rgb(var(--color-surface-600));
    font-weight: 500;
  }

  .hidden-input {
    display: none;
  }
  .tags li {
  display: contents;
}

  :global(.dark) .suggestions-wrap {
    background-color: rgba(31, 31, 31, 0.98);
  }

  :global(.dark) .suggestions {
    background-color: rgba(18, 18, 18, 0.98);
  }

  :global(.dark) .suggestions li {
    color: rgb(var(--color-surface-50));
  }
</style>




