// src/lib/modalState.js
// Global modal state - replaces Skeleton v2 getModalStore() / modalStore.trigger()
import { writable, get } from 'svelte/store';

const { subscribe, set } = writable(null);

let _responseCallback = null;
let _onCloseCallback = null;

export const modalState = {
  subscribe,

  /**
   * Open a modal.
   * @param {object} opts
   * @param {import('svelte').Component} opts.component - Svelte component to render
   * @param {object} [opts.props] - Props to pass to the component
   * @param {function} [opts.response] - Callback when modal responds (with value)
   * @param {function} [opts.onClose] - Callback always called when modal closes
   */
  trigger({ component, props, response, meta, title, onClose }) {
    _responseCallback = response || null;
    _onCloseCallback = onClose || null;
    set({
      component,
      props: { ...(props || {}), meta: meta || {}, title: title || '' }
    });
  },

  /**
   * Close modal and optionally send a response
   */
  close(responseValue) {
    if (_responseCallback && responseValue !== undefined) {
      _responseCallback(responseValue);
    }
    if (_onCloseCallback) {
      _onCloseCallback();
    }
    _responseCallback = null;
    _onCloseCallback = null;
    set(null);
  },

  /**
   * Send response without closing
   */
  respond(value) {
    if (_responseCallback) {
      _responseCallback(value);
    }
  }
};

