// assets/js/hooks.js
// Custom Phoenix LiveView hooks for the chat input
import { gsap } from "gsap"
// Modal animation hook with GSAP and outside click handling
export const ModalAnimation = {
  mounted() {
    // Store references
    this.modalOverlay = this.el;
    this.modalContent = this.el.querySelector('.modal-content');
    
    if (!this.modalContent) {
      console.error('Modal content element with class "modal-content" not found');
      return;
    }
    
    // Setup GSAP animations
    this.showAnimation();
    
    // Handle outside click
    this.handleOutsideClick = (e) => {
      // If click is on the overlay (not on modal content)
      if (e.target === this.modalOverlay) {
        // Send close_modal event to LiveView
        this.pushEvent('close_modal', {});
      }
    };
    
    // Add event listener
    this.modalOverlay.addEventListener('click', this.handleOutsideClick);
  },
  
  destroyed() {
    // Clean up event listener when component is removed
    if (this.modalOverlay && this.handleOutsideClick) {
      this.modalOverlay.removeEventListener('click', this.handleOutsideClick);
    }
  },
  
  showAnimation() {
    // Reset any previous animations
    gsap.set(this.modalContent, { scale: 0.8, opacity: 0 });
    
    // Create animation timeline
    const tl = gsap.timeline();
    
    // Animate modal content
    tl.to(this.modalContent, {
      duration: 0.3,
      scale: 1,
      opacity: 1,
      ease: "back.out(1.7)"
    });
  }
};

export const ChatInputAutoGrow = {
  mounted() {
    const textarea = this.el.querySelector("textarea");
    if (!textarea) return;
    // Set initial height
    textarea.style.height = "auto";
    textarea.style.overflowY = "hidden";
    const maxRows = 4;
    const updateHeight = () => {
      textarea.style.height = "auto";
      let lines = textarea.value.split("\n").length;
      let scrollHeight = textarea.scrollHeight;
      // Limit height to maxRows
      let lineHeight = parseInt(getComputedStyle(textarea).lineHeight) || 24;
      let maxHeight = lineHeight * maxRows;
      if (scrollHeight > maxHeight) {
        textarea.style.height = maxHeight + "px";
        textarea.style.overflowY = "auto";
      } else {
        textarea.style.height = scrollHeight + "px";
        textarea.style.overflowY = "hidden";
      }
    };
    textarea.addEventListener("input", updateHeight);
    // Allow Shift+Enter for new lines
    textarea.addEventListener("keydown", function(e) {
      if (e.key === "Enter" && !e.shiftKey) {
        // Let LiveView handle submit
        // Do not preventDefault
      }
    });
    updateHeight();
  }
};

// To use: import { ModalAnimation, ChatInputAutoGrow, ChatSendButton, ChatTokenStream, ChatAutoScroll, DropdownMenuHook, ModelDropdownHook } from "./hooks.js" in app.js and register with LiveSocket

// ChatAutoScroll: Ensures chat area always scrolls to bottom on mount, update, and new content
export const ChatAutoScroll = {
  mounted() {
    this.scrollTarget = document.getElementById("chat-messages") || this.el;
    this.scrollToBottom();
    // Observe for new messages or DOM changes
    this.observer = new MutationObserver(() => {
      // Use requestAnimationFrame to ensure DOM is updated before scrolling
      requestAnimationFrame(() => this.scrollToBottom());
    });
    this.observer.observe(this.scrollTarget, { childList: true, subtree: true });
    window.addEventListener("resize", this.scrollToBottom.bind(this));
  },
  updated() {
    this.scrollToBottom();
  },
  destroyed() {
    if (this.observer) this.observer.disconnect();
    window.removeEventListener("resize", this.scrollToBottom.bind(this));
  },
  scrollToBottom() {
    // Prefer explicit scroll target by id, fallback to this.el
    const el = document.getElementById("chat-messages") || this.el;
    if (!el) {
      return;
    }
    el.scrollTop = el.scrollHeight;
    // After scrolling, log the new scrollTop
    setTimeout(() => {
    }, 50);
  }
};


// Hook to incrementally render AI tokens in the chat area
export const ChatTokenStream = {
  mounted() {
    // The element to append tokens to (should be set with phx-hook="ChatTokenStream")
    this.buffer = "";
    this.el.innerHTML = "";
    this.handleEvent("ai_buffer_init", ({buffer}) => {
      this.buffer = buffer;
      this.el.textContent = buffer;
    });
    this.handleEvent("ai_token", ({token}) => {
      if (this.buffer.length > 0) {
        this.buffer += " " + token;
      } else {
        this.buffer = token;
      }
      this.el.textContent = this.buffer;
    });
    this.handleEvent("stream_done", () => {
      this.el.classList.remove("animate-pulse");
      // Clear buffer and DOM content after stream is done to prevent duplication
      this.buffer = "";
      this.el.textContent = "";
    });
  }
};

// Disables send button if textarea is empty
// Disables send button if textarea is empty. Adds debug logs and also checks on LiveView update.
export const DropdownMenuHook = {
  mounted() {
    console.log('[DropdownMenuHook] mounted', this.el);
    this.init();
  },
  updated() {
    console.log('[DropdownMenuHook] updated', this.el);
    this.init();
  },
  destroyed() {
    console.log('[DropdownMenuHook] destroyed', this.el);
    this.removeHandlers();
  },
  init() {
    this.trigger = this.el;
    // Use custom attribute to avoid Flowbite conflict
    const dropdownId = this.trigger.getAttribute('data-dropdown-menu-id') || this.trigger.getAttribute('data-dropdown-toggle');
    this.menu = dropdownId ? document.getElementById(dropdownId) : null;
    if (!this.trigger || !this.menu) return;
    // Remove previous handler if exists
    if (this._handlerAttached && this.openHandler) {
      this.trigger.removeEventListener('click', this.openHandler);
    }
    this.openHandler = (e) => {
      console.log('[DropdownMenuHook] openHandler triggered', this.el, this.menu);
      e.stopPropagation();
      if (this.menu.classList.contains('hidden')) {
        this.menu.classList.remove('hidden');
        gsap.fromTo(this.menu, { opacity: 0, y: -8 }, { opacity: 1, y: 0, duration: 0.18, ease: 'power2.out' });
        // Defer attaching outside click handler to avoid immediate close
        setTimeout(() => {
          document.addEventListener('mousedown', this.outsideHandler);
        }, 0);
      } else {
        this.closeMenu();
      }
    };
    this.outsideHandler = (e) => {
      if (!this.menu.contains(e.target) && !this.trigger.contains(e.target)) {
        this.closeMenu();
      }
    };
    this.trigger.addEventListener('click', this.openHandler);
  },
  closeMenu() {
    if (!this.menu.classList.contains('hidden')) {
      gsap.to(this.menu, { opacity: 0, y: -8, duration: 0.13, onComplete: () => {
        this.menu.classList.add('hidden');
        gsap.set(this.menu, { clearProps: 'all' });
      }});
      document.removeEventListener('mousedown', this.outsideHandler);
    }
  },
  removeHandlers() {
    if (this.trigger && this.openHandler) this.trigger.removeEventListener('click', this.openHandler);
    document.removeEventListener('mousedown', this.outsideHandler);
  }
};


// Dropdown hook for model selector
export const ModelDropdownHook = {
  mounted() {
    console.log('[ModelDropdownHook] mounted', this.el);
    this.init();
  },
  updated() {
    console.log('[ModelDropdownHook] updated', this.el);
    this.init();
  },
  destroyed() {
    console.log('[ModelDropdownHook] destroyed', this.el);
    this.removeHandlers();
  },
  init() {
    this.trigger = this.el;
    this.menu = document.getElementById('modelDropdownMenu');
    if (!this.trigger || !this.menu) return;
  
    // Remove previous click handler if exists
    if (this._handlerAttached && this.openHandler) {
      this.trigger.removeEventListener('click', this.openHandler);
    }
    // Remove previous outsideHandler if exists
    if (this._outsideHandlerAttached && this.outsideHandler) {
      document.removeEventListener('mousedown', this.outsideHandler);
      this._outsideHandlerAttached = false;
    }
  
    this.openHandler = (e) => {
      console.log('[ModelDropdownHook] openHandler triggered', this.el, this.menu);
      e.stopPropagation();
      if (this.menu.classList.contains('hidden')) {
        // Open dropdown
        this.menu.classList.remove('hidden');
        gsap.fromTo(this.menu, { opacity: 0, y: -8 }, { opacity: 1, y: 0, duration: 0.18, ease: 'power2.out' });
        // Remove previous outsideHandler before adding a new one
        if (this._outsideHandlerAttached && this.outsideHandler) {
          document.removeEventListener('mousedown', this.outsideHandler);
        }
        document.addEventListener('mousedown', this.outsideHandler);
        this._outsideHandlerAttached = true;
      } else {
        // Close dropdown by button click
        this.closeMenu();
      }
    };

    this.outsideHandler = (e) => {
      // If click is outside both trigger and menu, close
      if (!this.menu.contains(e.target) && !this.trigger.contains(e.target)) {
        this.closeMenu();
      }
    };

    this.trigger.addEventListener('click', this.openHandler);
    this._handlerAttached = true;
  },

  closeMenu() {
    if (!this.menu.classList.contains('hidden')) {
      gsap.to(this.menu, { opacity: 0, y: -8, duration: 0.13, onComplete: () => {
        this.menu.classList.add('hidden');
        gsap.set(this.menu, { clearProps: 'all' });
      }});
      if (this._outsideHandlerAttached && this.outsideHandler) {
        document.removeEventListener('mousedown', this.outsideHandler);
        this._outsideHandlerAttached = false;
      }
    }
  },

  removeHandlers() {
    if (this.trigger && this.openHandler) this.trigger.removeEventListener('click', this.openHandler);
    if (this._outsideHandlerAttached && this.outsideHandler) {
      document.removeEventListener('mousedown', this.outsideHandler);
      this._outsideHandlerAttached = false;
    }
    this._handlerAttached = false;
  }
};
// AI GENERATED SLOP. DONT KNOW HOW IT WORKS
export const ChatSendButton = {
  mounted() {
    const textarea = this.el.querySelector("textarea");
    const sendBtn = this.el.querySelector("#chat-send-btn");
    if (!textarea || !sendBtn) return;
    const check = () => {
      sendBtn.disabled = textarea.value.trim().length === 0;
    };
    textarea.addEventListener("input", check);
    check();
  },
  updated() {
    // Re-run check in case LiveView re-renders the form
    const textarea = this.el.querySelector("textarea");
    const sendBtn = this.el.querySelector("#chat-send-btn");
    if (!textarea || !sendBtn) return;
    const check = () => {
      sendBtn.disabled = textarea.value.trim().length === 0;
    };
    check();
  }
};

// Dropdown hook for chat three-dots menu


