#!/bin/bash
# Switch the autologin profile between the full desktop and the kiosk, then restart the session.
# Usage: sudo astroarch-session desktop|kiosk|status [--force]

PLASMALOGIN_CONF=/etc/plasmalogin.conf
DESKTOP_USER=astronaut
KIOSK_USER=astronaut-kiosk

_current_user() {
    sed -n 's/^User=//p' "$PLASMALOGIN_CONF" | head -1
}

_switch_to() {
    local user="$1" force="$2"
    if [ "$(_current_user)" = "$user" ]; then
        echo "Already on the $user profile."
        return 0
    fi
    # Restarting the session closes every app of the current profile
    if [ "$force" != "--force" ] && pgrep -x 'kstars|indiserver|phd2.bin' > /dev/null; then
        echo "KStars, INDI or PHD2 is running: switching would stop the imaging session." >&2
        echo "Close them first, or run again with --force." >&2
        return 1
    fi
    sed -i "s/^User=.*/User=$user/" "$PLASMALOGIN_CONF"
    echo "Switching to the $user profile, the session restarts now."
    systemctl restart display-manager.service
}

if [ "$(id -u)" -ne 0 ]; then
    echo "Run it with sudo: sudo astroarch-session ${1:-status}" >&2
    exit 1
fi

case "$1" in
    desktop) _switch_to "$DESKTOP_USER" "$2" ;;
    kiosk)
        if ! getent passwd "$KIOSK_USER" > /dev/null; then
            echo "There is no $KIOSK_USER user on this system." >&2
            exit 1
        fi
        _switch_to "$KIOSK_USER" "$2"
        ;;
    status|"") echo "Autologin profile: $(_current_user)" ;;
    *) echo "Usage: sudo astroarch-session desktop|kiosk|status [--force]" >&2; exit 1 ;;
esac
