// assets/js/hooks.js
// Custom Phoenix LiveView hooks for the chat input
import { gsap } from "gsap"

// CopyCode: LiveView hook for copy-to-clipboard on code blocks
export const CopyCode = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      const code = this.el.closest('.code-card')?.querySelector('pre code');
      if (code) {
        navigator.clipboard.writeText(code.innerText).then(() => {
          const original = this.el.innerHTML;
          this.el.innerHTML = '<span style="color:#3D5A80">Copied!</span>';
          setTimeout(() => { this.el.innerHTML = original; }, 1200);
        });
      }
    });
  }
};

// ChatInfiniteScroll: Infinite scroll for chat messages (pagination)
export const ChatInfiniteScroll = {
  mounted() {
    this.loading = false;
    this.handleScroll = async (e) => {
      // Only trigger if at top and not already loading
      if (this.el.scrollTop === 0 && !this.loading) {
        this.loading = true;
        // Save current scroll height to restore position after prepend
        const prevHeight = this.el.scrollHeight;
        this.pushEvent("load_more_messages", {}, {
          // After LiveView patch, restore scroll position to just below the newly loaded messages
          onReply: () => {
            // Wait for DOM update
            setTimeout(() => {
              const newHeight = this.el.scrollHeight;
              this.el.scrollTop = newHeight - prevHeight;
              this.loading = false;
            }, 60);
          }
        });
      }
    };
    this.el.addEventListener('scroll', this.handleScroll);
  },
  destroyed() {
    this.el.removeEventListener('scroll', this.handleScroll);
  }
};

// CopyMessage: LiveView hook for copy-to-clipboard on message bubbles
export const CopyMessage = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      // Find the closest message bubble (ai or user)
      let bubble = this.el.closest('.ai-message') || this.el.closest('.rounded-xl');
      if (!bubble) return;
      // Try to get the text content only (excluding button icons)
      // Remove all buttons temporarily to avoid copying their text
      let buttons = bubble.querySelectorAll('button');
      buttons.forEach(btn => btn.style.display = 'none');
      // Get the visible text
      let text = bubble.innerText.trim();
      // Restore buttons
      buttons.forEach(btn => btn.style.display = '');
      if (!text) return;
      navigator.clipboard.writeText(text).then(() => {
        // Swap icon to feedback
        const original = this.el.innerHTML;
        this.el.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>';
        setTimeout(() => { this.el.innerHTML = original; }, 1200);
      });
    });
  }
};


// Add CSS for code blocks in ai-message
const style = document.createElement('style');
style.innerHTML = `
.ai-message pre code {
  display: block;
  padding: 1em;
  border-radius: 0.5em;
  font-size: 0.95em;
  background: #f6f8fa;
  color: #24292f;
  overflow-x: auto;
}
`;
document.head.appendChild(style);


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

// ChatInputAutoGrow: Handles auto-growing textarea and Enter/Shift+Enter logic for chat input
export const ChatInputAutoGrow = {
  mounted() {
    console.log('[ChatInputAutoGrow] mounted, this.el:', this.el);
    // If hook is attached directly to the textarea, use this.el
    const textarea = this.el;
    if (!textarea) {
      console.warn('[ChatInputAutoGrow] No textarea found!');
      return;
    }
    console.log('[ChatInputAutoGrow] Found textarea:', textarea);

    // Set up to grow up to 10 lines
    const maxRows = 10;
    textarea.style.height = "auto";
    textarea.style.overflowY = "hidden";

    // Dynamically update height up to 10 lines, then scroll
    const updateHeight = () => {
      textarea.style.height = "auto";
      const lineHeight = parseInt(getComputedStyle(textarea).lineHeight) || 24;
      const maxHeight = lineHeight * maxRows;
      const scrollHeight = textarea.scrollHeight;
      if (scrollHeight > maxHeight) {
        textarea.style.height = maxHeight + "px";
        textarea.style.overflowY = "auto";
      } else {
        textarea.style.height = scrollHeight + "px";
        textarea.style.overflowY = "hidden";
      }
      console.log('[ChatInputAutoGrow] updateHeight fired. Height:', textarea.style.height, 'Rows:', textarea.value.split('\n').length);
    };

    textarea.addEventListener("input", (e) => {
      console.log('[ChatInputAutoGrow] input event:', e);
      updateHeight();
    });

    // Handle Enter/Shift+Enter logic
    textarea.addEventListener("keydown", function(e) {
      console.log('[ChatInputAutoGrow] keydown:', e.key, 'shift?', e.shiftKey);
      if (e.key === "Enter" && !e.shiftKey) {
        if (!textarea.value.trim()) {
          console.log('[ChatInputAutoGrow] Prevent submit: textarea empty');
          e.preventDefault();
          return false;
        }
        // Manually submit the form
        const form = textarea.closest("form");
        if (form) {
          e.preventDefault(); // Prevent newline
          form.requestSubmit ? form.requestSubmit() : form.submit();
          setTimeout(() => textarea.blur(), 0);
          console.log('[ChatInputAutoGrow] Enter pressed, form submitted');
        }
      } else if (e.key === "Enter" && e.shiftKey) {
        console.log('[ChatInputAutoGrow] Shift+Enter: allow new line');
      }
    });

    // Reset height on form submit for UX polish
    const form = textarea.closest("form");
    if (form) {
      form.addEventListener("submit", () => {
        console.log('[ChatInputAutoGrow] Form submitted, resetting textarea');
        setTimeout(() => {
          textarea.value = "";
          textarea.style.height = "auto";
          textarea.style.overflowY = "hidden";
        }, 10);
      });
    } else {
      console.warn('[ChatInputAutoGrow] No parent form found!');
    }

    // Initial height
    updateHeight();
  }
};

// To use: import { ModalAnimation, ChatInputAutoGrow, ChatSendButton, ChatTokenStream, ChatAutoScroll, DropdownMenuHook, ModelDropdownHook } from "./hooks.js" in app.js and register with LiveSocket

// ChatScrollManager: Infinite scroll + sticky auto-scroll for chat UX
export const ChatScrollManager = {
  mounted() {
    this.loading = false;
    this.stickToBottom = true; // true if user is at/near bottom
    this.scrollThreshold = 80; // px from bottom considered "at bottom"
    this.handleScroll = (e) => {
      // Infinite scroll: load more if at top
      if (this.el.scrollTop === 0 && !this.loading) {
        this.loading = true;
        const prevHeight = this.el.scrollHeight;
        this.pushEvent("load_more_messages", {}, {
          onReply: () => {
            setTimeout(() => {
              const newHeight = this.el.scrollHeight;
              this.el.scrollTop = newHeight - prevHeight;
              this.loading = false;
            }, 60);
          }
        });
      }
      // Sticky scroll: track if user is at/near bottom
      const distanceFromBottom = this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight;
      this.stickToBottom = distanceFromBottom < this.scrollThreshold;
    };
    this.el.addEventListener('scroll', this.handleScroll);
    // Initial scroll to bottom
    this.scrollToBottom();
  },
  updated() {
    // Only auto-scroll if user is at/near bottom
    if (this.stickToBottom) {
      this.scrollToBottom();
    }
  },
  destroyed() {
    this.el.removeEventListener('scroll', this.handleScroll);
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  }
};

// (removed old ChatAutoScroll and ChatInfiniteScroll hooks)


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
        this.buffer += "" + token;
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
    this.init();
  },
  updated() {
    this.init();
  },
  destroyed() {
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
      e.preventDefault();
      e.stopPropagation();
      if (this.menu.classList.contains('hidden')) {
        // Save original parent and next sibling for restoration
        if (!this._portalInfo) {
          this._portalInfo = {
            parent: this.menu.parentNode,
            next: this.menu.nextSibling
          };
        }
        // Move menu to body and make visible before measuring
        document.body.appendChild(this.menu);
        this.menu.classList.remove('hidden');
        // Wait one frame to ensure DOM update, then start positioning
        const updateDropdownPosition = () => {
          if (!this.menu || this.menu.classList.contains('hidden')) return;
          const rect = this.trigger.getBoundingClientRect();
          Object.assign(this.menu.style, {
            position: 'absolute',
            left: `${rect.right}px`,
            top: `${rect.top + rect.height / 2 - this.menu.offsetHeight / 4}px`,
            zIndex: 9999,
          });
          this._dropdownRAF = requestAnimationFrame(updateDropdownPosition);
        };
        requestAnimationFrame(updateDropdownPosition);
        gsap.fromTo(this.menu, { opacity: 0, y: -8 }, { opacity: 1, y: 0, duration: 0.18, ease: 'power2.out' });
        setTimeout(() => {
          document.addEventListener('mousedown', this.outsideHandler);
        }, 0);
        // Close dropdown on any button click inside menu
        this._menuButtonHandler = (evt) => {
          if (evt.target.closest('button')) {
            this.closeMenu();
          }
        };
        this.menu.addEventListener('click', this._menuButtonHandler);
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
        // --- PORTAL LOGIC END ---
        // Remove button click handler
        if (this._menuButtonHandler) {
          this.menu.removeEventListener('click', this._menuButtonHandler);
          this._menuButtonHandler = null;
        }
        // Stop position update loop
        if (this._dropdownRAF) {
          cancelAnimationFrame(this._dropdownRAF);
          this._dropdownRAF = null;
        }
        // Restore menu to original parent
        if (this._portalInfo) {
          const { parent, next } = this._portalInfo;
          if (parent && this.menu) {
            if (next && next.parentNode === parent) {
              parent.insertBefore(this.menu, next);
            } else {
              parent.appendChild(this.menu);
            }
          }
          // Remove inline styles
          this.menu.style.position = '';
          this.menu.style.left = '';
          this.menu.style.top = '';
          this.menu.style.zIndex = '';
          this._portalInfo = null;
        }
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
    this.init();
  },
  updated() {
    this.init();
  },
  destroyed() {
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
// ChatSendButton: Handles send/cancel button UI for streaming state
export const ChatSendButton = {
  mounted() {
    this.setup();
  },
  updated() {
    this.setup();
  },
  setup() {
    // Always re-query elements
    const textarea = this.el.querySelector("textarea");
    const sendBtn = this.el.querySelector("#chat-send-btn");
    if (!textarea || !sendBtn) return;

    // Remove previous input listener if present
    if (this._inputListener) {
      textarea.removeEventListener("input", this._inputListener);
    }

    // Enable/disable logic
    const check = () => {
      if (sendBtn.getAttribute("data-streaming") !== "true") {
        sendBtn.disabled = textarea.value.trim().length === 0;
      } else {
        sendBtn.disabled = false;
      }
    };

    this._inputListener = check;
    textarea.addEventListener("input", check);

    // Initial state
    check();
  }
};

// Dropdown hook for chat three-dots menu


