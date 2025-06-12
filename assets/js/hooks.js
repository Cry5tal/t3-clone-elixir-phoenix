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

// To use: import { ChatInputAutoGrow, ChatSendButton, ChatTokenStream } from "./hooks" in app.js and register with LiveSocket

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
