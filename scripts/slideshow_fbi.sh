#!/bin/bash
# Slideshow via fbi (Linux Framebuffer, kein X11)
# Konfiguration wird von install.sh gesetzt

MOUNT_POINT="${MOUNT_POINT:-/mnt/smb-fotos}"
SLIDESHOW_INTERVAL="${SLIDESHOW_INTERVAL:-10}"

echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink > /dev/null 2>&1
setterm -cursor off 2>/dev/null || true

while true; do
    IMAGES=$(find "$MOUNT_POINT" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | shuf)

    if [ -z "$IMAGES" ]; then
        echo "$(date): Keine Bilder in $MOUNT_POINT – warte 30 Sek..."
        sleep 30
        continue
    fi

    echo "$IMAGES" | tr '\n' '\0' | \
        xargs -0 fbi \
            -T 2 \
            -d /dev/fb0 \
            -a \
            -noverbose \
            -t "$SLIDESHOW_INTERVAL" \
            --cachemem 0

    sleep 5
done
