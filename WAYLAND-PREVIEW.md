# Wayland preview

Plasma 6.8 no longer has an X11 session, and today's AstroArch remote access (x0vncserver, XRDP, the kiosk) is built on X11. This branch lets you try the proposed replacement on a **test** system:

| Access | Today (X11) | Wayland preview |
| --- | --- | --- |
| RDP, port 3389 | XRDP, a separate session per login | KRdp (RemoteFX), the same desktop you see on HDMI/VNC |
| VNC, port 5900 | x0vncserver | TigerVNC `w0vncserver`, capped at 5 fps |
| Browser, port 8080 | noVNC → x0vncserver | noVNC → w0vncserver (unchanged service) |
| Kiosk | separate XRDP session | **not available** in the preview |
| No monitor | Xorg dummy driver | the HDMI output forced on in `cmdline.txt` |

Measurements from a Pi 5 are in the [Wayland bench report](https://claude.ai/artifact/9WEHFKx6mGp5qqVm1XbHSo).

## Before you start

- **Use a spare SD card or USB drive.** The preview upgrades to Plasma 6.8 and removes `plasma-x11-session`. There is no way back to X11 other than flashing the image again.
- Start from a fresh [AstroArch 2.0.10 image](https://releases.astroarch.me/astroarch-2.0.10.img.gz), with the Pi on a wired network so it can download about 300 packages.
- Use a proper power supply (the official 27 W one on a Pi 5).

## Install

Over SSH or in Konsole, as `astronaut`:

```bash
cd ~/.astroarch
git fetch https://github.com/teoteo/astroarch.git feat/wayland-preview
git checkout -b wayland-preview FETCH_HEAD
sudo bash scripts/wayland-preview.sh
```

The script asks you to type `YES`, upgrades the system, sets up the new services and offers to reboot. It takes 10–20 minutes. Afterwards, `git checkout main` puts the repository back: the preview copied its files into `/etc`, so they stay in place.

Options: `--yes` skips the questions, `--reboot` reboots at the end, `sudo VNC_PASSWORD=yourpassword bash scripts/wayland-preview.sh` sets your own VNC password.

## Connect

| Client | Address | Login |
| --- | --- | --- |
| RDP (Windows Remote Desktop, Remmina, aRDP, Windows App) | `astroarch.local:3389` | user `astronaut`, your system password. Accept the certificate once. |
| VNC (RealVNC, TigerVNC, bVNC) | `astroarch.local:5900` | VNC password (`astro` unless you set another) |
| Browser | `http://astroarch.local:8080/vnc.html` | the same VNC password |

VNC and RDP show the same desktop, so everyone connected sees the same screen.

## What to report

Please post in the AstroArch Discord, with your Pi model and RAM:

1. Did RDP, VNC and noVNC all connect after a cold boot, with no monitor and nobody at the Pi?
2. Which clients worked, and which didn't (especially Android and iPad)?
3. How did a real session go: Ekos capture, PHD2 guiding, plate solving? Was guiding as good as on X11?
4. CPU numbers. Run this during the session, once with no client connected and once with your usual client:

   ```bash
   bash ~/.astroarch/scripts/wayland-preview-sample.sh "my label" 60
   ```

   It prints the CPU of the compositor, the remote server and the astronomy apps as a percentage of one core.
5. For any problem, the output of:

   ```bash
   cat /etc/astroarch/wayland-preview
   journalctl --user -b -u app-org.kde.krdpserver -u app-org.astroarch.vnc --no-pager | tail -50
   ```

## Known limits

- No kiosk session yet.
- RDP no longer opens a separate session per login. It shares the desktop of the logged-in user.
- Every remote path costs more CPU than on X11, much more when the screen changes fast (live view, panning the sky map). For just watching a session, VNC is the lightest. Prefer one viewer at a time on a Pi 4.
- RDP uses RemoteFX. You can try H.264, which costs more CPU on a still screen but sends about four times less data when the screen changes fast:

  ```bash
  mkdir -p ~/.config/systemd/user/app-org.kde.krdpserver.service.d
  printf '[Service]\nEnvironment=KRDP_DISABLE_H264=0\n' > ~/.config/systemd/user/app-org.kde.krdpserver.service.d/h264.conf
  systemctl --user daemon-reload && systemctl --user restart app-org.kde.krdpserver
  ```

  Clients that decode H.264 with OpenH264 (Royal TSX and Remmina on macOS, for example) then show a white screen, until KPipeWire's frame-rate fix ships ([bug 526931](https://bugs.kde.org/show_bug.cgi?id=526931)). Delete `h264.conf` and run the last line again to go back.
- KRdp in Plasma 6.8 sends no sound.
