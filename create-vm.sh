#!/usr/bin/env bash
# Legt auf einem Proxmox-VE-Host eine Debian-13-VM mit Cloud-Init an.
#
# Aufruf als root auf dem Proxmox-Host (Shell im Webinterface oder per SSH):
#   bash create-vm.sh
#
# Das Skript fragt alle Werte ab, zeigt eine Zusammenfassung und legt die VM
# erst nach Bestätigung an. Am Proxmox-Host selbst wird nichts geändert,
# außer dass das Debian-Cloud-Image heruntergeladen wird.
set -euo pipefail

IMAGE_BASE_URL=https://cloud.debian.org/images/cloud/trixie/latest
IMAGE_NAME=debian-13-genericcloud-amd64.qcow2
IMAGE_DIR=/var/lib/vz/template/cloud-images

die()  { echo "Fehler: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# ask VARIABLE "Frage" "Standardwert"
ask() {
    local __var=$1 prompt=$2 default=${3:-} answer
    if [ -n "$default" ]; then
        read -r -p "$prompt [$default]: " answer
    else
        read -r -p "$prompt: " answer
    fi
    printf -v "$__var" '%s' "${answer:-$default}"
}

confirm() {
    local answer
    read -r -p "$1 [j/N]: " answer
    [[ $answer =~ ^[jJyY]$ ]]
}

[ "$(id -u)" -eq 0 ] || die "Bitte als root auf dem Proxmox-Host ausführen."
command -v qm >/dev/null && command -v pvesm >/dev/null \
    || die "qm/pvesm nicht gefunden. Das Skript läuft nur auf einem Proxmox-VE-Host."

echo
echo "Debian-13-VM für das Dev-Portal anlegen"
echo "---------------------------------------"
echo "Enter übernimmt den Wert in eckigen Klammern."
echo

# --- VMID ---------------------------------------------------------------
while :; do
    ask VMID "VMID" "$(pvesh get /cluster/nextid)"
    [[ $VMID =~ ^[0-9]+$ ]] || { echo "Bitte nur Ziffern."; continue; }
    pvesh get /cluster/nextid --vmid "$VMID" >/dev/null 2>&1 && break
    echo "VMID $VMID ist bereits belegt."
done

# --- Name ---------------------------------------------------------------
while :; do
    ask VMNAME "Name der VM (auch Hostname)" "dev-portal"
    [[ $VMNAME =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] && break
    echo "Erlaubt sind Buchstaben, Ziffern und Bindestriche."
done

# --- Storage ------------------------------------------------------------
echo
echo "Storages für VM-Disks:"
mapfile -t STORAGES < <(pvesm status --content images --enabled 1 2>/dev/null | awk 'NR>1 && $3=="active" {print $1}')
[ ${#STORAGES[@]} -gt 0 ] || die "Kein aktiver Storage für VM-Disks (Inhalt 'images') gefunden."
pvesm status --content images --enabled 1 | awk 'NR>1 && $3=="active" {printf "  %-20s %-10s frei: %.0f GB\n", $1, $2, $6/1024/1024}'
DEFAULT_STORAGE=${STORAGES[0]}
for s in "${STORAGES[@]}"; do [ "$s" = local-lvm ] && DEFAULT_STORAGE=local-lvm; done
while :; do
    ask STORAGE "Storage" "$DEFAULT_STORAGE"
    printf '%s\n' "${STORAGES[@]}" | grep -qx "$STORAGE" && break
    echo "Unbekannter Storage."
done

# --- Bridge -------------------------------------------------------------
echo
mapfile -t BRIDGES < <(for d in /sys/class/net/*/bridge; do [ -d "$d" ] && basename "$(dirname "$d")"; done)
[ ${#BRIDGES[@]} -gt 0 ] || die "Keine Netzwerk-Bridge gefunden."
echo "Bridges: ${BRIDGES[*]}"
DEFAULT_BRIDGE=${BRIDGES[0]}
for b in "${BRIDGES[@]}"; do [ "$b" = vmbr0 ] && DEFAULT_BRIDGE=vmbr0; done
while :; do
    ask BRIDGE "Bridge" "$DEFAULT_BRIDGE"
    printf '%s\n' "${BRIDGES[@]}" | grep -qx "$BRIDGE" && break
    echo "Unbekannte Bridge."
done

# --- CPU, RAM, Disk -----------------------------------------------------
echo
HOST_CORES=$(nproc)
MEM_AVAIL_MB=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
echo "Host: $HOST_CORES CPU-Kerne, $MEM_AVAIL_MB MB RAM verfügbar"
while :; do
    ask CORES "CPU-Kerne" "4"
    [[ $CORES =~ ^[0-9]+$ ]] && [ "$CORES" -ge 1 ] && [ "$CORES" -le "$HOST_CORES" ] && break
    echo "Bitte eine Zahl zwischen 1 und $HOST_CORES."
done
while :; do
    ask RAM "RAM in MB (empfohlen mindestens 4096)" "8192"
    [[ $RAM =~ ^[0-9]+$ ]] && [ "$RAM" -ge 2048 ] || { echo "Bitte mindestens 2048."; continue; }
    if [ "$RAM" -gt "$MEM_AVAIL_MB" ]; then
        confirm "Achtung: mehr als verfügbar ($MEM_AVAIL_MB MB). Trotzdem?" || continue
    fi
    break
done
while :; do
    ask DISK "Disk in GB (empfohlen mindestens 30)" "50"
    [[ $DISK =~ ^[0-9]+$ ]] && [ "$DISK" -ge 10 ] && break
    echo "Bitte mindestens 10."
done

# --- Netzwerk -----------------------------------------------------------
echo
echo "IP-Adresse: leer lassen für DHCP (empfohlen, dann im Router fest reservieren)"
echo "oder fest angeben mit Präfix, z. B. 10.0.0.50/24."
while :; do
    ask STATIC_IP "Feste IP" ""
    if [ -z "$STATIC_IP" ]; then
        IPCONFIG="ip=dhcp"
        break
    fi
    [[ $STATIC_IP =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]] || { echo "Format: a.b.c.d/präfix"; continue; }
    ask GATEWAY "Gateway" ""
    ask DNS "DNS-Server" "$GATEWAY"
    IPCONFIG="ip=$STATIC_IP,gw=$GATEWAY"
    break
done

# --- Benutzer und SSH-Schlüssel ----------------------------------------
echo
ask CIUSER "Benutzername in der VM" "debian"
DEFAULT_KEY=""
SSH_LOGIN_OPT=""
for k in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
    [ -f "$k" ] && { DEFAULT_KEY=$k; break; }
done
echo "Öffentlicher SSH-Schlüssel für den Login (leer = neuen Schlüssel auf diesem Host erzeugen)."
echo "Du kannst auch den Pfad zu einem Schlüssel deines PCs angeben, den du vorher hierher kopiert hast."
while :; do
    ask SSHKEY "Pfad zum öffentlichen Schlüssel" "$DEFAULT_KEY"
    if [ -z "$SSHKEY" ]; then
        SSHKEY=~/.ssh/id_ed25519_$VMNAME.pub
        [ -f "$SSHKEY" ] || ssh-keygen -q -t ed25519 -N '' -C "root@$(hostname) -> $VMNAME" -f "${SSHKEY%.pub}"
        echo "Neuer Schlüssel: ${SSHKEY%.pub}"
        SSH_LOGIN_OPT="-i ${SSHKEY%.pub} "
    fi
    [ -f "$SSHKEY" ] && grep -q '^ssh-' "$SSHKEY" && break
    echo "Datei nicht gefunden oder kein öffentlicher SSH-Schlüssel."
done
echo "Optional: Passwort für den Login über die Proxmox-Konsole (leer = keins, nur SSH)."
read -r -s -p "Passwort: " CIPASSWORD; echo

confirm "VM mit dem Proxmox-Host starten (onboot)?" && ONBOOT=1 || ONBOOT=0

# --- Zusammenfassung ----------------------------------------------------
cat <<SUMMARY

Zusammenfassung
  VMID / Name:  $VMID / $VMNAME
  Storage:      $STORAGE ($DISK GB)
  Bridge:       $BRIDGE ($IPCONFIG)
  CPU / RAM:    $CORES Kerne (Typ host) / $RAM MB
  Benutzer:     $CIUSER, Schlüssel $SSHKEY
  Onboot:       $ONBOOT
SUMMARY
confirm "VM jetzt anlegen?" || die "Abgebrochen, nichts geändert."

# --- Image herunterladen und prüfen ------------------------------------
mkdir -p "$IMAGE_DIR"
IMAGE=$IMAGE_DIR/$IMAGE_NAME
info "Prüfe Debian-Cloud-Image"
curl -fsSL "$IMAGE_BASE_URL/SHA512SUMS" -o "$IMAGE_DIR/SHA512SUMS"
check_image() { (cd "$IMAGE_DIR" && grep " $IMAGE_NAME\$" SHA512SUMS | sha512sum -c --status -); }
if [ -f "$IMAGE" ] && check_image; then
    echo "Vorhandenes Image ist aktuell."
else
    info "Lade $IMAGE_NAME herunter"
    curl -fL --progress-bar "$IMAGE_BASE_URL/$IMAGE_NAME" -o "$IMAGE.part"
    mv "$IMAGE.part" "$IMAGE"
    check_image || die "Prüfsumme des Images stimmt nicht."
fi

# --- VM anlegen ---------------------------------------------------------
info "Lege VM $VMID an"
qm create "$VMID" --name "$VMNAME" --ostype l26 --machine q35 \
    --cpu host --cores "$CORES" --sockets 1 --memory "$RAM" --balloon 0 \
    --net0 "virtio,bridge=$BRIDGE" --scsihw virtio-scsi-single \
    --agent enabled=1 --onboot "$ONBOOT" --serial0 socket --vga serial0
qm set "$VMID" --scsi0 "$STORAGE:0,import-from=$IMAGE,discard=on,iothread=1,ssd=1" >/dev/null
qm disk resize "$VMID" scsi0 "${DISK}G" >/dev/null
CI_ARGS=(--ide2 "$STORAGE:cloudinit" --boot order=scsi0 --ciuser "$CIUSER"
         --sshkeys "$SSHKEY" --ipconfig0 "$IPCONFIG" --ciupgrade 0)
[ -n "${DNS:-}" ] && CI_ARGS+=(--nameserver "$DNS")
[ -n "$CIPASSWORD" ] && CI_ARGS+=(--cipassword "$CIPASSWORD")
qm set "$VMID" "${CI_ARGS[@]}" >/dev/null
qm start "$VMID"

MAC=$(qm config "$VMID" | sed -n 's/^net0: virtio=\([0-9A-Fa-f:]*\).*/\1/p')

# --- IP herausfinden ----------------------------------------------------
IP=""
if [ -n "$STATIC_IP" ]; then
    IP=${STATIC_IP%/*}
else
    info "Warte auf die DHCP-Adresse (bis zu 3 Minuten)"
    SUBNET=$(ip -4 -o addr show dev "$BRIDGE" 2>/dev/null | awk '{print $4}' | head -1)
    for _ in $(seq 1 18); do
        sleep 10
        # Bei einem /24-Netz kurz alle Adressen anpingen, damit die ARP-Tabelle gefüllt wird
        if [[ $SUBNET == */24 ]]; then
            PREFIX=${SUBNET%.*}
            for h in $(seq 1 254); do ping -c1 -W1 "$PREFIX.$h" >/dev/null 2>&1 & done; wait
        fi
        IP=$(ip -4 neigh show dev "$BRIDGE" | grep -i "$MAC" | awk '{print $1}' | head -1)
        [ -n "$IP" ] && break
    done
fi

cat <<DONE

Fertig. VM $VMID "$VMNAME" läuft.
  MAC-Adresse: $MAC
  IP-Adresse:  ${IP:-nicht gefunden, bitte im Router unter der MAC-Adresse nachsehen}

Nächste Schritte (siehe README):
  1. Im Router für die MAC-Adresse eine feste IP reservieren (bei DHCP).
  2. Einloggen:  ssh ${SSH_LOGIN_OPT}$CIUSER@${IP:-<IP>}
  3. In der VM:  sudo apt-get update && sudo apt-get install -y git
                 git clone https://github.com/DevLunaris/dev-portal-template.git mein-projekt
                 cd mein-projekt && ./bootstrap.sh
DONE
