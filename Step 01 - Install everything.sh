/bin/bash <<'DAN_STEP_01'
# STEP 01 - Installs the apps and tools. M1 Max / 64 GB Mac. About 10-20 minutes.
# Quit Parallels/Windows first. Paste this whole block into Terminal and press Return.
set -Eeuo pipefail
umask 022
fail() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || fail "Run this on the Mac, not Windows."
[[ "$(uname -m)" == arm64 ]] || fail "Open the normal Mac Terminal, not a Rosetta one."
[[ "$(id -u)" != 0 ]] || fail "Paste as your normal Mac user, not root."
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[[ "$MACOS_MAJOR" -ge 15 ]] || fail "Update macOS to version 15 or newer, then paste again."
[[ "$(sysctl -n hw.memsize)" -ge 64424509440 ]] || fail "This setup is intended for the 64 GB Mac."
if pgrep -f 'prl_vm_app|prl_client_app' >/dev/null 2>&1; then
  fail "Parallels is open. Shut down Windows, quit Parallels, then paste again."
fi
FREE_KB="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
[[ "$FREE_KB" -ge 157286400 ]] || fail "Need about 150 GB of free disk space. Free some space, then paste again."

ROOT="$HOME/Library/Application Support/DanLocalAI"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ROOT/logs" "$HOME/.omlx/models" "$HOME/Desktop"
exec > >(tee "$ROOT/logs/step01-$STAMP.log") 2>&1
trap 'echo "Step 01 stopped at line $LINENO. Log: $ROOT/logs/step01-$STAMP.log"' ERR
TMP="$(mktemp -d)"
SUDO_PID=""
cleanup() {
  [[ -z "$SUDO_PID" ]] || kill "$SUDO_PID" 2>/dev/null || true
  hdiutil detach "$TMP/mount" -quiet >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT
/usr/bin/caffeinate -is -w "$$" >/dev/null 2>&1 &

echo "Enter your Mac login password when requested (nothing shows while you type)."
sudo -v </dev/tty
( while kill -0 "$$" 2>/dev/null; do sudo -n -v || exit; sleep 45; done ) >/dev/null 2>&1 &
SUDO_PID=$!

echo "=== 1/6 Homebrew and developer tools ==="
export HOMEBREW_NO_ANALYTICS=1
if [[ ! -x /opt/homebrew/bin/brew ]]; then
  curl -fSL --retry 3 --connect-timeout 20 \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$TMP/brew-install.sh"
  NONINTERACTIVE=1 /bin/bash "$TMP/brew-install.sh" </dev/tty
fi
[[ -x /opt/homebrew/bin/brew ]] || fail "Homebrew installation did not complete."
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install git node@24 python@3.13
brew install hf || brew install huggingface-cli
cat > "$ROOT/environment.sh" <<'ENVIRONMENT'
export PATH="/opt/homebrew/opt/node@24/bin:/opt/homebrew/opt/python@3.13/libexec/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"
ENVIRONMENT
source "$ROOT/environment.sh"
for profile in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  touch "$profile"
  grep -Fq 'DanLocalAI/environment.sh' "$profile" || \
    printf '\nsource "$HOME/Library/Application Support/DanLocalAI/environment.sh"\n' >> "$profile"
done
git --version; node --version; python3 --version; hf --version

# The oMLX app (not the Homebrew build) ships the fast Qwen kernels precompiled.
echo "=== 2/6 oMLX (the local AI engine) ==="
if [[ ! -d /Applications/oMLX.app ]]; then
  if [[ "$MACOS_MAJOR" -ge 26 ]]; then
    OMLX_DMG="oMLX-0.6.4-macos26-27.dmg"
    OMLX_SHA="53f1506c2385e8920a67198b72d1fe09351c1b3538be9c6bdeb78e5277d06d93"
  else
    OMLX_DMG="oMLX-0.6.4-macos15-sequoia.dmg"
    OMLX_SHA="5a90c7ae4a3f4ca8bf10dcc83d7f7395281e2ffb2a85d630c95e9720848e47cd"
  fi
  curl -fSL --retry 3 --connect-timeout 20 \
    "https://github.com/jundot/omlx/releases/download/v0.6.4/$OMLX_DMG" -o "$TMP/oMLX.dmg"
  printf '%s  %s\n' "$OMLX_SHA" "$TMP/oMLX.dmg" | shasum -a 256 -c -
  mkdir -p "$TMP/mount"
  hdiutil attach "$TMP/oMLX.dmg" -readonly -nobrowse -mountpoint "$TMP/mount" -quiet
  [[ -d "$TMP/mount/oMLX.app" ]] || fail "oMLX.app is missing from the installer."
  sudo ditto "$TMP/mount/oMLX.app" /Applications/oMLX.app
  hdiutil detach "$TMP/mount" -quiet
else
  echo "oMLX already installed."
fi

echo "=== 3/6 Buzz ==="
if [[ ! -d /Applications/Buzz.app && ! -d "$HOME/Applications/Buzz.app" ]]; then
  curl -fSL --retry 3 --connect-timeout 20 \
    https://github.com/block/buzz/releases/download/desktop-v0.5.23/Buzz_0.5.23_aarch64.dmg \
    -o "$TMP/Buzz.dmg"
  printf '%s  %s\n' \
    '9197dde29a09ade77f56677e07cb4d6a9d7d1a6a157d7212f0a050144059c5b2' \
    "$TMP/Buzz.dmg" | shasum -a 256 -c -
  mkdir -p "$TMP/mount"
  hdiutil attach "$TMP/Buzz.dmg" -readonly -nobrowse -mountpoint "$TMP/mount" -quiet
  [[ -d "$TMP/mount/Buzz.app" ]] || fail "Buzz.app is missing from the installer."
  sudo ditto "$TMP/mount/Buzz.app" /Applications/Buzz.app
  hdiutil detach "$TMP/mount" -quiet
else
  echo "Buzz already installed."
fi

# A settings file that already exists makes oMLX skip its setup wizard.
# Local-only server (127.0.0.1), so no login is needed on this Mac.
echo "=== 4/6 oMLX settings ==="
if [[ ! -f "$HOME/.omlx/settings.json" ]]; then
  cat > "$HOME/.omlx/settings.json" <<'SETTINGS'
{
  "version": "1.0",
  "server": { "host": "127.0.0.1", "port": 8000, "auto_start_on_launch": true },
  "scheduler": { "max_concurrent_requests": 4 },
  "auth": { "api_key": "dan-local", "skip_api_key_verification": true }
}
SETTINGS
  chmod 600 "$HOME/.omlx/settings.json"
else
  echo "Existing oMLX settings kept."
fi

# macOS lets the GPU use about 48 of the 64 GB by default. This Mac only runs
# Buzz and the models, so allow 52 GB (12 GB stays for macOS). Reapplied at boot.
echo "=== 5/6 GPU memory limit ==="
DAEMON=/Library/LaunchDaemons/local.dan.gpu-memory.plist
sudo tee "$DAEMON" >/dev/null <<'DAEMONPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.dan.gpu-memory</string>
  <key>ProgramArguments</key>
  <array><string>/usr/sbin/sysctl</string><string>iogpu.wired_limit_mb=53248</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
DAEMONPLIST
sudo chown root:wheel "$DAEMON"
sudo chmod 644 "$DAEMON"
sudo launchctl bootout system/local.dan.gpu-memory >/dev/null 2>&1 || true
sudo launchctl bootstrap system "$DAEMON" || true
sudo /usr/sbin/sysctl iogpu.wired_limit_mb=53248 || echo "WARNING: GPU memory limit not raised. Everything still works."

echo "=== 6/6 Desktop buttons ==="
cat > "$HOME/Desktop/Start Dan AI.command" <<'LAUNCHER'
#!/bin/bash
ROOT="$HOME/Library/Application Support/DanLocalAI"
source "$ROOT/environment.sh"
if pgrep -f 'prl_vm_app|prl_client_app' >/dev/null 2>&1; then
  echo "WARNING: Parallels/Windows is open. Close it before using the big models."
fi
# Let Buzz find the developer tools and wait patiently for slow local models.
launchctl setenv PATH "$PATH"
launchctl setenv BUZZ_AGENT_LLM_TIMEOUT_SECS 3600
launchctl setenv BUZZ_AGENT_MAX_ROUNDS 30
launchctl setenv BUZZ_AGENT_MAX_PARALLEL_TOOLS 1
echo "Starting the AI engine (oMLX)..."
open -gj /Applications/oMLX.app
for i in {1..60}; do
  curl --noproxy '*' -fsS --max-time 2 http://127.0.0.1:8000/v1/models >/dev/null 2>&1 && break
  sleep 2
done
if curl --noproxy '*' -fsS --max-time 2 http://127.0.0.1:8000/v1/models >/dev/null 2>&1; then
  echo "AI engine is ready."
else
  echo "AI engine did not answer. Click the oMLX icon at the top of the screen and choose Start Server."
fi
if [[ -d /Applications/Buzz.app ]]; then open /Applications/Buzz.app; else open "$HOME/Applications/Buzz.app"; fi
LAUNCHER
cat > "$HOME/Desktop/Stop Dan AI.command" <<'STOPPER'
#!/bin/bash
# Frees the memory so Parallels/Windows can be used.
[[ -x "$HOME/.omlx/bin/omlx" ]] && "$HOME/.omlx/bin/omlx" stop
osascript -e 'quit app "oMLX"' >/dev/null 2>&1
echo "AI engine stopped. It is now safe to open Parallels/Windows."
STOPPER
chmod 755 "$HOME/Desktop/Start Dan AI.command" "$HOME/Desktop/Stop Dan AI.command"

printf '\n============================================================\n'
printf ' STEP 01 COMPLETE. Now paste Step 02 (the model downloads).\n'
printf '============================================================\n'
DAN_STEP_01
