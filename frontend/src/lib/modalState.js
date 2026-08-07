// src/lib/modalState.js
// Global modal state - replaces Skeleton v2 getModalStore() / modalStore.trigger()
import { writable, get } from 'svelte/store';

const { subscribe, set } = writable(null);

let _modalStack = [];
let _responseCallback = null;
let _onCloseCallback = null;

function withBackState(modalData) {
  if (!modalData) return null;
  return {
    ...modalData,
    props: {
      ...(modalData.props || {}),
      canGoBack: _modalStack.length > 0,
    },
  };
}

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
    const current = get({ subscribe });
    if (current) {
      _modalStack.push({
        modalData: current,
        responseCallback: _responseCallback,
        onCloseCallback: _onCloseCallback,
      });
    }

    _responseCallback = response || null;
    _onCloseCallback = onClose || null;
    set(withBackState({
      component,
      props: { ...(props || {}), meta: meta || {}, title: title || '' }
    }));
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

    const previous = _modalStack.pop();
    if (previous) {
      _responseCallback = previous.responseCallback || null;
      _onCloseCallback = previous.onCloseCallback || null;
      set(withBackState(previous.modalData));
      return;
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

