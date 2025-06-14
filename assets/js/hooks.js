// assets/js/hooks.js
// Custom Phoenix LiveView hooks for the chat input
import { gsap } from "gsap"
import MarkdownIt from "markdown-it";
import markdownItKatex from "markdown-it-katex";
import markdownItTaskLists from "markdown-it-task-lists";
import markdownItFootnote from "markdown-it-footnote";
import hljs from 'highlight.js/lib/core';
import elixir from 'highlight.js/lib/languages/elixir';
import javascript from 'highlight.js/lib/languages/javascript';
import python from 'highlight.js/lib/languages/python';
import 'highlight.js/styles/github.css';

// Register languages you expect
hljs.registerLanguage('elixir', elixir);
hljs.registerLanguage('javascript', javascript);
hljs.registerLanguage('python', python);

/**
 * MarkdownRenderer: Renders markdown content inside the element using markdown-it.
 * Usage: Add phx-hook="MarkdownRenderer" to any element whose innerText is markdown.
 * Only use for trusted/escaped content (AI messages).
 */
export const MarkdownRenderer = {
  mounted() {
    this.md = new MarkdownIt({
      html: false, // disable raw HTML for safety
      linkify: true,
      breaks: true
    })
      .use(markdownItKatex)
      .use(markdownItTaskLists)
      .use(markdownItFootnote);
    this.renderMarkdown();
    // Highlight code blocks on mount
    this.highlightCodeBlocks();
  },
  updated() {
    this.renderMarkdown();
    // Highlight code blocks on update
    this.highlightCodeBlocks();
  },
  renderMarkdown() {
    // Get the raw text content (as sent from LiveView)
    const raw = this.el.innerText;
    // Render markdown to HTML
    const html = this.md.render(raw);
    // Set the HTML content (safe for markdown-it with html: false)
    this.el.innerHTML = html;
  },
  highlightCodeBlocks() {
    // Highlight all code blocks inside this element
    this.el.querySelectorAll('pre code').forEach((block) => {
      hljs.highlightElement(block);
    });
  }
};

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


