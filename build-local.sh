#!/bin/bash
# Baut VoiceInk Notch direkt auf diesem Mac und legt die App in den Programme-Ordner.
# Voraussetzung: Xcode ist installiert und wurde einmal geöffnet.
# Aufruf im Terminal:
#   curl -fsSL https://raw.githubusercontent.com/yannickschollmayer/notch/main/build-local.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/yannickschollmayer/notch/main"
WORK="$HOME/VoiceInk-Notch"
UPSTREAM=$(curl -fsSL "$REPO_RAW/UPSTREAM" | tr -d '[:space:]')

echo "→ Xcode prüfen"
if ! xcodebuild -version; then
  echo "Xcode fehlt oder ist nicht eingerichtet. Bitte Xcode aus dem App Store installieren und einmal öffnen."
  exit 1
fi
xcodebuild -downloadComponent MetalToolchain || echo "  (Metal-Werkzeuge schon vorhanden oder nicht nötig)"

echo "→ Whisper-Baustein vorbereiten"
DEST="$HOME/VoiceInk-Dependencies/whisper.cpp/build-apple"
if [ ! -d "$DEST/whisper.xcframework" ]; then
  mkdir -p "$DEST"
  TMP=$(mktemp -d)
  curl -fL -o "$TMP/whisper.zip" "https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-b5454-xcframework.zip"
  unzip -q "$TMP/whisper.zip" -d "$TMP/x"
  cp -R "$(find "$TMP/x" -type d -name whisper.xcframework | head -1)" "$DEST/"
fi

echo "→ VoiceInk-Quellcode holen"
if [ ! -d "$WORK/.git" ]; then
  git clone https://github.com/Beingpax/VoiceInk.git "$WORK"
fi
cd "$WORK"
git fetch -q origin
git checkout -q -f "$UPSTREAM"
git clean -fdq

echo "→ Notch-Änderungen einspielen"
PATCHES=$(curl -fsSL "https://api.github.com/repos/yannickschollmayer/notch/contents/patches" \
  | grep -o '"name": *"[^"]*\.patch"' | cut -d'"' -f4 | sort)
for p in $PATCHES; do
  echo "  $p"
  curl -fsSL "$REPO_RAW/patches/$p" | git apply --whitespace=nowarn
done

echo "→ App bauen (beim ersten Mal 10–20 Minuten)"
make local LOCAL_CODESIGN_IDENTITY=-

APP="$HOME/Downloads/VoiceInk.app"
codesign --force --sign - --preserve-metadata=entitlements,flags,runtime \
  --requirements '=designated => identifier "com.prakashjoshipax.VoiceInk"' "$APP"

echo "→ In den Programme-Ordner legen"
osascript -e 'tell application "VoiceInk" to quit' 2>/dev/null || true
rm -rf /Applications/VoiceInk.app
ditto "$APP" /Applications/VoiceInk.app
xattr -cr /Applications/VoiceInk.app
open /Applications/VoiceInk.app
echo "Fertig. VoiceInk Notch läuft."
