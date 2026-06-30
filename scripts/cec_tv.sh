#!/bin/bash
# TV per HDMI-CEC steuern
# Wird von cron aufgerufen

ACTION="${1:-}"

case "$ACTION" in
    on)
        echo "on 0"  | cec-client -s -d 1
        sleep 2
        echo "as"    | cec-client -s -d 1
        ;;
    off)
        echo "standby 0" | cec-client -s -d 1
        ;;
    status)
        echo "pow 0" | cec-client -s -d 1
        ;;
    scan)
        echo "scan"  | cec-client -s -d 1
        ;;
    *)
        echo "Verwendung: $0 {on|off|status|scan}"
        exit 1
        ;;
esac
