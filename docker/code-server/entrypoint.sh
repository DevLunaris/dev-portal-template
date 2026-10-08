#!/bin/sh
set -e

# Standardeinstellungen (Workspace Trust aus, Chat-Seitenleiste zu,
# keine Willkommensseite) in die Benutzereinstellungen übernehmen
node /usr/local/share/code-server-defaults/merge-settings.js \
    /usr/local/share/code-server-defaults/settings.json \
    "$HOME/.local/share/code-server/User/settings.json"

# Erweiterungen beim ersten Start installieren (landen im Home-Volume)
for ext in bmewburn.vscode-intelephense-client Vue.volar; do
    if ! code-server --list-extensions | grep -qix "$ext"; then
        code-server --install-extension "$ext" || echo "Erweiterung $ext konnte nicht installiert werden"
    fi
done

# --disable-workspace-trust: Projektordner gilt immer als vertrauenswürdig,
# kein Restricted Mode
exec code-server \
    --bind-addr 0.0.0.0:8080 \
    --auth password \
    --disable-telemetry \
    --disable-update-check \
    --disable-workspace-trust \
    /home/dev/project
