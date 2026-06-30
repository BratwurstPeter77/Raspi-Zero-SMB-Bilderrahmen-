#!/bin/bash
# ============================================================
# install.sh — Pi Zero W Slideshow + CEC
# Aufruf nach git clone:
#   cp config.env.example config.env && nano config.env
#   sudo bash install.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# Config prüfen
if [ ! -f "$CONFIG_FILE" ]; then
    echo ""
    echo "FEHLER: config.env nicht gefunden!"
    echo "Bitte zuerst anlegen:"
    echo "  cp $SCRIPT_DIR/config.env.example $SCRIPT_DIR/config.env"
    echo "  nano $SCRIPT_DIR/config.env"
    echo ""
    exit 1
fi

# Config laden
source "$CONFIG_FILE"

# Defaults setzen falls nicht in config.env
MOUNT_POINT="${MOUNT_POINT:-/mnt/smb-fotos}"
DISPLAY_USER="${DISPLAY_USER:-pi}"
CEC_ON_HOUR="${CEC_ON_HOUR:-7}"
CEC_OFF_HOUR="${CEC_OFF_HOUR:-17}"
SLIDESHOW_INTERVAL="${SLIDESHOW_INTERVAL:-10}"

echo "======================================================"
echo " Pi Zero W – Slideshow + CEC Install"
echo " SMB-Host:    $SMB_HOST"
echo " Mount:       $MOUNT_POINT"
echo " User:        $DISPLAY_USER"
echo " TV an/aus:   ${CEC_ON_HOUR}:00 / ${CEC_OFF_HOUR}:00"
echo " Intervall:   ${SLIDESHOW_INTERVAL}s pro Bild"
echo "======================================================"
echo ""

# [1] Pakete
echo "[1/6] Pakete installieren..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    fbi \
    cifs-utils \
    fbset \
    cec-utils \
    console-setup

# [2] SMB Credentials (aus config.env, nur root lesbar)
echo "[2/6] SMB-Credentials speichern..."
sudo bash -c "cat > /etc/smb-slideshow.creds << EOF
username=$SMB_USER
password=$SMB_PASS
domain=$SMB_DOMAIN
EOF"
sudo chmod 600 /etc/smb-slideshow.creds

# [3] fstab Mount
echo "[3/6] SMB fstab-Eintrag setzen..."
sudo mkdir -p "$MOUNT_POINT"
FSTAB_ENTRY="$SMB_HOST $MOUNT_POINT cifs credentials=/etc/smb-slideshow.creds,ro,uid=1000,gid=1000,iocharset=utf8,_netdev,nofail,x-systemd.automount 0 0"
if grep -qF "$MOUNT_POINT" /etc/fstab; then
    echo "  -> Eintrag existiert bereits, überspringe."
else
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
fi
sudo systemctl daemon-reload

# [4] Scripts installieren (Env-Variablen einbetten)
echo "[4/6] Scripts installieren..."
sudo mkdir -p "/home/$DISPLAY_USER/scripts"

# slideshow_fbi.sh mit gesetzten Werten
sudo bash -c "sed \
    's|MOUNT_POINT=\"\${MOUNT_POINT:-/mnt/smb-fotos}\"|MOUNT_POINT=\"$MOUNT_POINT\"|; \
     s|SLIDESHOW_INTERVAL=\"\${SLIDESHOW_INTERVAL:-10}\"|SLIDESHOW_INTERVAL=\"$SLIDESHOW_INTERVAL\"|' \
    \"$SCRIPT_DIR/scripts/slideshow_fbi.sh\" > \"/home/$DISPLAY_USER/scripts/slideshow_fbi.sh\""

sudo cp "$SCRIPT_DIR/scripts/cec_tv.sh" "/home/$DISPLAY_USER/scripts/cec_tv.sh"
sudo chown -R "$DISPLAY_USER:$DISPLAY_USER" "/home/$DISPLAY_USER/scripts/"
sudo chmod +x "/home/$DISPLAY_USER/scripts/slideshow_fbi.sh"
sudo chmod +x "/home/$DISPLAY_USER/scripts/cec_tv.sh"
sudo usermod -aG video "$DISPLAY_USER"

# [5] systemd Service
echo "[5/6] systemd Slideshow-Service einrichten..."
sudo bash -c "cat > /etc/systemd/system/slideshow.service << EOF
[Unit]
Description=SMB Foto-Slideshow (fbi Framebuffer)
After=network-online.target remote-fs.target
Wants=network-online.target

[Service]
User=$DISPLAY_USER
ExecStart=/home/$DISPLAY_USER/scripts/slideshow_fbi.sh
Restart=always
RestartSec=10
StandardInput=tty
TTYPath=/dev/tty2
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=no

[Install]
WantedBy=multi-user.target
EOF"
sudo systemctl daemon-reload
sudo systemctl enable slideshow.service

# [6] CEC Cron-Jobs
echo "[6/6] CEC Cron-Jobs setzen (${CEC_ON_HOUR}:00 an / ${CEC_OFF_HOUR}:00 aus)..."
(crontab -u "$DISPLAY_USER" -l 2>/dev/null | grep -v "cec_tv.sh") | crontab -u "$DISPLAY_USER" - || true
(
  crontab -u "$DISPLAY_USER" -l 2>/dev/null
  echo "# TV per CEC einschalten"
  echo "0 $CEC_ON_HOUR  * * * /home/$DISPLAY_USER/scripts/cec_tv.sh on"
  echo "# TV per CEC in Standby"
  echo "0 $CEC_OFF_HOUR * * * /home/$DISPLAY_USER/scripts/cec_tv.sh off"
) | crontab -u "$DISPLAY_USER" -

# HDMI config.txt
echo "HDMI-Einstellungen setzen (HD Ready 720p)..."
CONFIG="/boot/config.txt"
[ -f /boot/firmware/config.txt ] && CONFIG="/boot/firmware/config.txt"

declare -A HDMI_SETTINGS=(
    ["hdmi_force_hotplug"]="1"
    ["hdmi_drive"]="2"
    ["hdmi_group"]="1"
    ["hdmi_mode"]="4"
)
for KEY in "${!HDMI_SETTINGS[@]}"; do
    VALUE="${HDMI_SETTINGS[$KEY]}"
    if grep -q "^$KEY" "$CONFIG"; then
        sudo sed -i "s/^$KEY.*/$KEY=$VALUE/" "$CONFIG"
    else
        echo "$KEY=$VALUE" | sudo tee -a "$CONFIG"
    fi
done

echo ""
echo "======================================================"
echo " Installation abgeschlossen!"
echo ""
echo " Testen:"
echo "   sudo mount -a && ls $MOUNT_POINT"
echo "   /home/$DISPLAY_USER/scripts/cec_tv.sh scan"
echo "   /home/$DISPLAY_USER/scripts/cec_tv.sh on"
echo ""
echo " Dann: sudo reboot"
echo "======================================================"
