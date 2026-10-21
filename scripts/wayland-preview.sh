#!/bin/bash
# Wayland preview: switch a TEST AstroArch system to Plasma Wayland, with KRdp for RDP (3389)
# and TigerVNC's w0vncserver for VNC (5900) and noVNC (8080). See WAYLAND-PREVIEW.md.
# There is no way back to X11 other than flashing the image again.
# Usage: sudo bash scripts/wayland-preview.sh [--yes] [--reboot]

# Exit on the first error, if any
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_USER="${SUDO_USER:-astronaut}"
VNC_PASSWORD="${VNC_PASSWORD:-astro}"
CERT_DIR=/etc/astroarch/krdp
KEEP_X11_HOOK=/etc/pacman.d/hooks/astroarch-keep-x11-session.hook

ASSUME_YES=0
REBOOT=0
for arg in "$@"; do
    case "$arg" in
        --yes) ASSUME_YES=1 ;;
        --reboot) REBOOT=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "Run it with sudo: sudo bash $0" >&2
    exit 1
fi
if [ "$TARGET_USER" = root ]; then
    echo "Run it with sudo from the desktop user (e.g. astronaut), not from a root shell" >&2
    exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo "This switches this system to the Plasma Wayland preview:"
echo "  - full system upgrade, removing plasma-x11-session"
echo "  - RDP (3389) by KRdp, sized to the client window; VNC (5900) and noVNC (8080) by w0vncserver"
echo "  - SDDM is replaced by Plasma Login Manager, with autologin"
echo "  - xrdp, x0vncserver and the kiosk session are disabled"
echo "There is no way back to X11 other than flashing the image again. Use a test SD card."
if [ "$ASSUME_YES" -ne 1 ]; then
    read -r -p "Type YES to continue: " answer
    [ "$answer" = "YES" ] || { echo "Nothing changed."; exit 1; }
fi

# The keep-X11 hook would abort the upgrade on purpose
rm -f "$KEEP_X11_HOOK"

# Full upgrade; --ask 4 accepts removing plasma-x11-session, which conflicts with Plasma >= 6.8
pacman -Syu --needed --noconfirm --ask 4 krdp plasma-login-manager

for f in /usr/share/wayland-sessions/plasma.desktop /usr/bin/krdpserver /usr/bin/w0vncserver /usr/bin/plasmalogin; do
    if [ ! -e "$f" ]; then
        echo "$f is missing after the upgrade, stopping before touching the session" >&2
        exit 1
    fi
done
echo "Plasma: $(pacman -Q plasma-workspace), $(pacman -Q krdp), $(pacman -Q tigervnc)"

# Stop starting the X11 remote stack at boot; it keeps running until the reboot
systemctl disable x0vncserver.service xrdp.service xrdp-sesman.service xrdp-autostart-kiosk.service 2>/dev/null || true

# Plasma Login Manager instead of SDDM: KRdp's RemoteAccess mode hands the physical seat to it
install -Dm644 "$REPO_DIR/configs/wayland-preview/plasmalogin.conf" /etc/plasmalogin.conf
sed -i "s/^User=.*/User=$TARGET_USER/" /etc/plasmalogin.conf
systemctl disable sddm.service 2>/dev/null || true
systemctl enable plasmalogin.service

# After an RDP client leaves, give the screen back to the desktop session so VNC/noVNC see it again
install -Dm755 "$REPO_DIR/scripts/astroarch-rdp-return.sh" /usr/local/bin/astroarch-rdp-return.sh
install -Dm644 "$REPO_DIR/systemd/astroarch-rdp-return.service" /etc/systemd/system/astroarch-rdp-return.service
systemctl enable astroarch-rdp-return.service

# No blanking, suspend or lock: nobody is at the Pi to wake it
install -Dm644 -b "$REPO_DIR/configs/wayland-preview/powerdevilrc" /etc/xdg/powerdevilrc
install -Dm644 -b "$REPO_DIR/configs/wayland-preview/kscreenlockerrc" /etc/xdg/kscreenlockerrc

# VNC: portal app id, user units and the permission that avoids a dialog on a headless Pi
install -Dm644 "$REPO_DIR/configs/wayland-preview/org.astroarch.vnc.desktop" /usr/local/share/applications/org.astroarch.vnc.desktop
install -Dm644 "$REPO_DIR/systemd/user/app-org.astroarch.vnc.service" /etc/systemd/user/app-org.astroarch.vnc.service
install -Dm644 "$REPO_DIR/systemd/user/astroarch-remote-grant.service" /etc/systemd/user/astroarch-remote-grant.service

# RDP: KRdp drop-in and a fixed certificate, so clients don't warn after every boot
install -Dm644 "$REPO_DIR/systemd/user/app-org.kde.krdpserver.service.d/10-astroarch.conf" /etc/systemd/user/app-org.kde.krdpserver.service.d/10-astroarch.conf
install -d -m 755 "$CERT_DIR"
if [ ! -f "$CERT_DIR/krdp.crt" ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj /CN=astroarch \
        -keyout "$CERT_DIR/krdp.key" -out "$CERT_DIR/krdp.crt" 2>/dev/null
fi
chown root:"$TARGET_USER" "$CERT_DIR/krdp.key" "$CERT_DIR/krdp.crt"
chmod 640 "$CERT_DIR/krdp.key" "$CERT_DIR/krdp.crt"

# User side: RDP login with the system password, VNC password, units started with Plasma
sudo -u "$TARGET_USER" HOME="$TARGET_HOME" LC_ALL=C.UTF-8 kwriteconfig6 --file krdpserverrc --group General --key SystemUserEnabled true
sudo -u "$TARGET_USER" HOME="$TARGET_HOME" LC_ALL=C.UTF-8 kwriteconfig6 --file krdpserverrc --group General --key ListenPort 3389
sudo -u "$TARGET_USER" mkdir -p "$TARGET_HOME/.config/astroarch" "$TARGET_HOME/.config/systemd/user/plasma-workspace.target.wants"
printf '%s\n' "$VNC_PASSWORD" | vncpasswd -f > "$TARGET_HOME/.config/astroarch/vnc.passwd"
chown "$TARGET_USER": "$TARGET_HOME/.config/astroarch/vnc.passwd"
chmod 600 "$TARGET_HOME/.config/astroarch/vnc.passwd"
WANTS="$TARGET_HOME/.config/systemd/user/plasma-workspace.target.wants"
for unit in /etc/systemd/user/astroarch-remote-grant.service /etc/systemd/user/app-org.astroarch.vnc.service /usr/lib/systemd/user/app-org.kde.krdpserver.service; do
    sudo -u "$TARGET_USER" ln -sfn "$unit" "$WANTS/$(basename "$unit")"
done

# Remember what was applied, for bug reports
echo "wayland-preview applied $(date -Is) from $(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)" > /etc/astroarch/wayland-preview

echo "Done. After the reboot: RDP on port 3389 (user $TARGET_USER, system password), VNC on 5900 and noVNC on 8080 (VNC password: $VNC_PASSWORD)."
if [ "$REBOOT" -eq 1 ]; then
    systemctl reboot
elif [ "$ASSUME_YES" -ne 1 ]; then
    read -r -p "Reboot now? [y/N] " answer
    [[ "$answer" =~ ^[yY]$ ]] && systemctl reboot
fi
exit 0
