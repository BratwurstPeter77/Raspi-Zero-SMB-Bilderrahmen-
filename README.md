# Pi Zero W – SMB Foto-Slideshow mit CEC TV-Steuerung

Raspberry Pi Zero W zeigt Bilder von einem SMB-Share per HDMI als Slideshow an. Der angeschlossene TV wird jeden Morgen automatisch per HDMI-CEC eingeschaltet und abends wieder in Standby versetzt.

***

## Übersicht

| Funktion | Technik |
|---|---|
| Bildanzeige | `fbi` (Linux Framebuffer, kein X11) |
| Netzwerkfreigabe | SMB/CIFS via `/etc/fstab` |
| TV Ein/Aus | `cec-client` (HDMI-CEC) |
| Automatisierung | `cron` + `systemd` |
| OS | Raspberry Pi OS Lite 32-bit |

***

## Voraussetzungen

- Raspberry Pi Zero W (mit WLAN)
- Micro-SD-Karte (mind. 8 GB)
- Mini-HDMI → HDMI-Kabel
- TV oder Monitor mit HDMI (**CEC optional** – Slideshow läuft auch ohne CEC-fähigem TV)
- SMB-Freigabe im Heimnetz (NAS, Windows-PC, o.ä.)

***

## Empfohlenes OS

**Raspberry Pi OS Lite (32-bit)** – Bullseye oder Bookworm

Im Raspberry Pi Imager unter: *Raspberry Pi OS (other) → Raspberry Pi OS Lite (32-bit)*

**Beim Flashen in den „Erweiterten Einstellungen" direkt setzen:**
- WLAN SSID + Passwort
- SSH aktivieren
- Hostname (z.B. `bilderrahmen`)
- User `pi` mit Passwort

***

## Dateien

| Datei | Zweck |
|---|---|
| `setup_complete.sh` | Einmaliges Komplettsetup (alles in einem Schritt) |
| `slideshow_fbi.sh` | Slideshow-Script (fbi, Framebuffer) |
| `cec_tv.sh` | TV per CEC ein-/ausschalten |

***

## Schnellstart

### 1. Werte anpassen

Oben in `setup_complete.sh`:
```bash
SMB_HOST="//192.168.1.100/fotos"   # IP deines NAS + Freigabename
SMB_USER="deinuser"
SMB_PASS="deinpasswort"
SMB_DOMAIN="WORKGROUP"
CEC_ON_HOUR="7"     # TV an um 07:00 Uhr
CEC_OFF_HOUR="17"   # TV aus um 17:00 Uhr
```

### 2. Alle Dateien auf den Pi kopieren
```bash
scp setup_complete.sh slideshow_fbi.sh cec_tv.sh pi@bilderrahmen.local:~/
```

### 3. Setup ausführen
```bash
ssh pi@bilderrahmen.local
chmod +x setup_complete.sh slideshow_fbi.sh cec_tv.sh
sudo bash setup_complete.sh
```

### 4. Testen (vor dem Reboot)
```bash
# SMB-Mount prüfen
sudo mount -a
ls /mnt/smb-fotos

# CEC: Gerätescan (zeigt TV und Pi im HDMI-Bus)
/home/pi/scripts/cec_tv.sh scan

# CEC: TV manuell ein/aus testen
/home/pi/scripts/cec_tv.sh on
/home/pi/scripts/cec_tv.sh off
/home/pi/scripts/cec_tv.sh status
```

### 5. Reboot
```bash
sudo reboot
```

***

## Was nach dem Reboot passiert

```
Boot
 └── systemd
      ├── slideshow.service (After=network-online + remote-fs)
      │    └── slideshow_fbi.sh
      │         ├── find /mnt/smb-fotos …| shuf → Zufällige Reihenfolge
      │         ├── fbi -T 2 -d /dev/fb0 -a -t 10
      │         └── Loop: nach Durchlauf neu einlesen (=Cache-Check)
      │
      └── cron (user pi)
           ├── 07:00 → cec_tv.sh on  (TV einschalten + Pi als aktive Quelle)
           └── 17:00 → cec_tv.sh off (TV in Standby)
```

***

## HDMI-CEC Details

### Was ist CEC?

HDMI-CEC (Consumer Electronics Control) ist ein Protokoll über die HDMI-Leitung, das Geräte gegenseitig steuern lässt – z.B. kann der Pi den TV einschalten, ohne zusätzliche Kabel oder IR-Blaster.

Jeder TV-Hersteller nennt es anders:

| Hersteller | Name für CEC |
|---|---|
| Samsung | Anynet+ |
| LG | SimpLink |
| Sony | BRAVIA Sync |
| Philips | EasyLink |
| Panasonic | VIERA Link |

**Am TV aktivieren:** Einstellungen → Bild/System → HDMI-CEC / Anynet+ / SimpLink → **Ein**

### CEC-Befehle

```bash
# TV einschalten
echo "on 0" | cec-client -s -d 1

# Pi als aktive Quelle setzen (TV wechselt auf HDMI-Eingang)
echo "as" | cec-client -s -d 1

# TV in Standby
echo "standby 0" | cec-client -s -d 1

# Stromstatus abfragen
echo "pow 0" | cec-client -s -d 1

# Alle CEC-Geräte im Bus scannen (zur Diagnose)
echo "scan" | cec-client -s -d 1
```

### Kein CEC-fähiger TV?

Kein Problem – der Slideshow-Service läuft völlig unabhängig von CEC. Die Cron-Jobs werden trotzdem ausgeführt, passiert aber einfach nichts. Sobald irgendwann ein CEC-fähiger TV angeschlossen wird, funktioniert es automatisch ohne weitere Änderungen.

***

## Cron-Zeiten anpassen

```bash
crontab -e
```

Aktuelle Einträge (Beispiel 07:00 / 17:00):
```
0 7  * * * /home/pi/scripts/cec_tv.sh on
0 17 * * * /home/pi/scripts/cec_tv.sh off
```

Nur Wochentags (Mo–Fr):
```
0 7  * * 1-5 /home/pi/scripts/cec_tv.sh on
0 17 * * 1-5 /home/pi/scripts/cec_tv.sh off
```

Wochenende andere Zeiten:
```
0 7  * * 1-5 /home/pi/scripts/cec_tv.sh on
0 17 * * 1-5 /home/pi/scripts/cec_tv.sh off
0 9  * * 6,7 /home/pi/scripts/cec_tv.sh on
0 22 * * 6,7 /home/pi/scripts/cec_tv.sh off
```

***

## Slideshow-Einstellungen

In `slideshow_fbi.sh`:

| Variable | Standard | Bedeutung |
|---|---|---|
| `SLIDESHOW_INTERVAL` | `10` | Sekunden pro Bild |
| `MOUNT_POINT` | `/mnt/smb-fotos` | Pfad zum SMB-Mount |

Änderungen nach dem ersten Setup übernehmen:
```bash
nano /home/pi/scripts/slideshow_fbi.sh
sudo systemctl restart slideshow
```

***

## HDMI-Einstellungen (`/boot/config.txt`)

Das Setup setzt automatisch folgende Werte für HD Ready (1280×720):

```ini
hdmi_force_hotplug=1   # HDMI aktiv auch ohne erkannten Monitor
hdmi_drive=2           # HDMI-Modus (kein DVI) – wichtig für CEC!
hdmi_group=1           # CEA (TV-Standards)
hdmi_mode=4            # 720p @ 60 Hz
```

> **Wichtig:** `hdmi_drive=2` ist Pflicht für CEC – im DVI-Modus (`hdmi_drive=1`) funktioniert CEC nicht.

Für Full HD: `hdmi_mode=16` (1080p @ 60 Hz)

***

## Manuelle Befehle

```bash
# Slideshow-Status
sudo systemctl status slideshow

# Slideshow neu starten
sudo systemctl restart slideshow

# Slideshow-Logs live
journalctl -u slideshow -f

# CEC-TV manuell steuern
/home/pi/scripts/cec_tv.sh on
/home/pi/scripts/cec_tv.sh off
/home/pi/scripts/cec_tv.sh status
/home/pi/scripts/cec_tv.sh scan

# SMB-Mount manuell prüfen
sudo mount -a && ls /mnt/smb-fotos

# fbi direkt testen (aus SSH-Session)
fbi -T 2 -d /dev/fb0 -a -noverbose -t 5 /mnt/smb-fotos/*.jpg
```

***

## Troubleshooting

| Problem | Lösung |
|---|---|
| Schwarzer Bildschirm | `hdmi_force_hotplug=1` in `/boot/config.txt` prüfen |
| CEC funktioniert nicht | `hdmi_drive=2` setzen, CEC am TV aktivieren, `cec_tv.sh scan` testen |
| `fbi: cannot open framebuffer` | `sudo usermod -aG video pi` dann neu einloggen |
| SMB-Mount fehlt | `journalctl -u systemd-networkd` – WLAN verbunden? |
| Bilder laden nicht neu | Service neu starten: `sudo systemctl restart slideshow` |
| TV schaltet bei Standby nicht aus | Pi muss aktive Quelle sein: `echo "as" \| cec-client -s -d 1` |
| Cron läuft nicht | `crontab -l` prüfen, `journalctl -u cron` |
