# 🖼️ Pi Zero W – SMB Slideshow + CEC TV-Steuerung

Raspberry Pi Zero W zeigt Bilder von einem SMB-Share per HDMI als Slideshow an.  
Der angeschlossene TV wird per HDMI-CEC automatisch ein- und ausgeschaltet.

## Features

- 📁 Bilder von SMB-Freigabe (NAS, Windows-PC, o.ä.)
- 🖥️ Anzeige per `fbi` direkt über Linux-Framebuffer (kein X11, leichtgewichtig)
- 🔄 Neue/gelöschte Bilder werden automatisch beim nächsten Durchlauf geladen
- 📺 TV per HDMI-CEC zu konfigurierbaren Zeiten ein-/ausschalten
- ⚙️ Vollautomatischer Start per systemd

## Voraussetzungen

- Raspberry Pi Zero W
- **Raspberry Pi OS Lite (32-bit)** – Bullseye oder Bookworm
- HDMI-Verbindung zum TV/Monitor
- SMB-Freigabe im Heimnetz

> **CEC ist optional** – die Slideshow läuft auch ohne CEC-fähigem TV.

***

## Installation

### 1. Repo klonen

```bash
git clone https://github.com/DEIN-USERNAME/pi-slideshow.git
cd pi-slideshow
```

### 2. Config anlegen

```bash
cp config.env.example config.env
nano config.env
```

Folgende Werte eintragen:

```bash
SMB_HOST="//192.168.1.100/fotos"   # IP + Freigabename
SMB_USER="deinuser"
SMB_PASS="deinpasswort"
SMB_DOMAIN="WORKGROUP"
CEC_ON_HOUR="7"                    # TV an um 07:00
CEC_OFF_HOUR="17"                  # TV aus um 17:00
SLIDESHOW_INTERVAL="10"            # Sekunden pro Bild
```

### 3. Installieren

```bash
sudo bash install.sh
```

### 4. Testen

```bash
# SMB-Mount prüfen
sudo mount -a && ls /mnt/smb-fotos

# CEC-Geräte scannen
/home/pi/scripts/cec_tv.sh scan

# TV manuell ein/aus
/home/pi/scripts/cec_tv.sh on
/home/pi/scripts/cec_tv.sh off
```

### 5. Reboot

```bash
sudo reboot
```

***

## Projektstruktur

```
pi-slideshow/
├── install.sh              # Installationsscript (einmalig ausführen)
├── config.env.example      # Konfigurationsvorlage (→ config.env kopieren)
├── scripts/
│   ├── slideshow_fbi.sh    # Slideshow (fbi, Framebuffer)
│   └── cec_tv.sh           # TV per HDMI-CEC steuern
├── .gitignore
├── LICENSE
└── README.md
```

***

## Boot-Chain

```
Boot
 └── systemd
      ├── slideshow.service  (After=network-online + remote-fs)
      │    └── slideshow_fbi.sh
      │         ├── find /mnt/smb-fotos | shuf
      │         ├── fbi -T 2 -d /dev/fb0 -a -t 10
      │         └── Loop: nach Durchlauf Dateiliste neu laden
      └── cron (user pi)
           ├── HH:00 → cec_tv.sh on
           └── HH:00 → cec_tv.sh off
```

***

## CEC

| Hersteller | Name für CEC |
|---|---|
| Samsung | Anynet+ |
| LG | SimpLink |
| Sony | BRAVIA Sync |
| Philips | EasyLink |
| Panasonic | VIERA Link |

Am TV aktivieren: *Einstellungen → System → HDMI-CEC → Ein*

> `hdmi_drive=2` in `/boot/config.txt` ist Pflicht für CEC – wird von `install.sh` automatisch gesetzt.

### Cron-Zeiten anpassen

```bash
crontab -e
```

Beispiel nur Wochentags:
```
0 7  * * 1-5 /home/pi/scripts/cec_tv.sh on
0 17 * * 1-5 /home/pi/scripts/cec_tv.sh off
```

***

## HDMI-Einstellungen

`install.sh` setzt automatisch für HD Ready (1280×720):

```ini
hdmi_force_hotplug=1
hdmi_drive=2
hdmi_group=1
hdmi_mode=4      # 720p @ 60Hz – für Full HD: hdmi_mode=16
```

***

## Manuelle Befehle

```bash
sudo systemctl status slideshow     # Status
sudo systemctl restart slideshow    # Neu starten
journalctl -u slideshow -f          # Logs live

/home/pi/scripts/cec_tv.sh scan     # CEC-Geräte anzeigen
/home/pi/scripts/cec_tv.sh on       # TV ein
/home/pi/scripts/cec_tv.sh off      # TV aus
/home/pi/scripts/cec_tv.sh status   # TV-Status
```

***

## Troubleshooting

| Problem | Lösung |
|---|---|
| Schwarzer Bildschirm | `hdmi_force_hotplug=1` in `/boot/config.txt` prüfen |
| CEC funktioniert nicht | `hdmi_drive=2` setzen, CEC am TV aktivieren |
| `fbi: cannot open framebuffer` | `sudo usermod -aG video pi`, neu einloggen |
| SMB-Mount fehlt | WLAN verbunden? `journalctl -u systemd-networkd` |
| Bilder nicht aktuell | `sudo systemctl restart slideshow` |

***

## Lizenz

MIT – siehe [LICENSE](LICENSE)
