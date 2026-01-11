#!/bin/bash

set -e

# Dateien
IP_FILE="/opt/vpn_bypass_ips.txt"
IP_FILE_PREVIOUS="/opt/vpn_bypass_ips_previous.txt"
IP_FILE_CLEAN="/opt/vpn_bypass_ips_clean.txt"

# GitHub Raw URL
IP_URL="https://raw.githubusercontent.com/KevinGandalf/vpn-bypass/main/vpn_bypass_ips.txt"

# ------------------------------------------------------------
# 1. Standard-Gateway und Device automatisch ermitteln
# ------------------------------------------------------------
DEFAULT_ROUTE=$(ip route show default | head -n 1)

if [[ -z "$DEFAULT_ROUTE" ]]; then
    echo "$(date) - ❌ Kein Default-Gateway gefunden!"
    exit 1
fi

GATEWAY=$(echo "$DEFAULT_ROUTE" | awk '{for(i=1;i<=NF;i++) if ($i=="via") print $(i+1)}')
DEVICE=$(echo "$DEFAULT_ROUTE" | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')

if [[ -z "$GATEWAY" || -z "$DEVICE" ]]; then
    echo "$(date) - ❌ Gateway oder Device konnte nicht ermittelt werden!"
    exit 1
fi

echo "$(date) - ✅ Default-Gateway: $GATEWAY"
echo "$(date) - ✅ Default-Device : $DEVICE"

# ------------------------------------------------------------
# 2. IP-Liste herunterladen
# ------------------------------------------------------------
echo "$(date) - Lade IP-Adressen von GitHub herunter..."
curl -fsSL "$IP_URL" -o "$IP_FILE"

if [[ ! -s "$IP_FILE" ]]; then
    echo "$(date) - ❌ IP-Datei ist leer oder konnte nicht geladen werden!"
    exit 1
fi

# ------------------------------------------------------------
# 3. IP-Liste bereinigen (Kommentare, Leerzeilen, Duplikate)
# ------------------------------------------------------------
echo "$(date) - Bereinige IP-Liste (Duplikate entfernen)..."

grep -Ev '^\s*#|^\s*$' "$IP_FILE" \
    | sort -u \
    > "$IP_FILE_CLEAN"

# ------------------------------------------------------------
# 4. IP-Adressen einlesen
# ------------------------------------------------------------
mapfile -t ip_list < "$IP_FILE_CLEAN"

# ------------------------------------------------------------
# 5. Routen setzen
# ------------------------------------------------------------
for ip in "${ip_list[@]}"; do
    ip_only="${ip%%/*}"

    if ip route show "$ip_only" &>/dev/null; then
        echo "$(date) - Route für $ip_only existiert bereits, überspringe"
    else
        echo "$(date) - Füge Route hinzu: $ip_only via $GATEWAY dev $DEVICE"
        ip route add "$ip_only" via "$GATEWAY" dev "$DEVICE"
    fi
done

# ------------------------------------------------------------
# 6. Aktuelle Liste sichern
# ------------------------------------------------------------
cp "$IP_FILE_CLEAN" "$IP_FILE_PREVIOUS"

echo "$(date) - ✅ Abgleich abgeschlossen."
