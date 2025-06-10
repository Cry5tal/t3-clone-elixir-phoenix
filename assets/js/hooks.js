// assets/js/hooks.js
// Custom Phoenix LiveView hooks for the chat input

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

// To use: import { ChatInputAutoGrow, ChatSendButton } from "./hooks" in app.js and register with LiveSocket

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
