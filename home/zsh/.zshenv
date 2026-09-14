# Environment for every zsh (interactive or not).
# Interactive-only config (aliases, prompt, completions) belongs in ~/.zshrc.

# Flutter: use /opt/flutter directly and bypass the AUR unionfs wrapper.
export PATH="/opt/flutter/bin:$PATH"

# Android SDK
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
