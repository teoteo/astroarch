#!/bin/bash
# KRdp's RemoteAccess mode hands the physical seat to the login screen and leaves the user session
# locked on disconnect: on a headless Pi nobody can log back in, and VNC/noVNC lose the desktop.
# When no RDP client is connected, give the seat back to the autologin user and unlock the session.
RDP_PORT="${RDP_PORT:-3389}"

while true; do
    sleep 5
    ss -Htn state established "( sport = :$RDP_PORT )" | grep -q . && continue
    # The user Plasma Login Manager logs in automatically; astroarch-session can change it
    AUTOLOGIN_USER=$(sed -n 's/^User=//p' /etc/plasmalogin.conf | head -1)
    SESSION=$(loginctl list-sessions --no-legend | awk -v u="$AUTOLOGIN_USER" '$3==u && $4=="seat0" {print $1; exit}')
    [ -n "$SESSION" ] || continue
    [ "$(loginctl show-session "$SESSION" -p Active --value)" = "no" ] || continue
    loginctl activate "$SESSION" && loginctl unlock-session "$SESSION" && echo "Gave seat0 back to session $SESSION"
    # Repaint everything: on a still desktop VNC would otherwise get only the parts that change
    sleep 2
    runuser -u "$AUTOLOGIN_USER" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$AUTOLOGIN_USER")/bus" \
        qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure > /dev/null 2>&1
done
