# Parallelize pacman download to 5
sed -i 's/#ParallelDownloads = 5/ParallelDownloads=5/g' /etc/pacman.conf

# Add astroarch pacman repo to pacman.conf (it must go first)
sed -i 's|\[core\]|\[astromatto\]\nSigLevel = Optional TrustAll\nServer = http://astroarch.astromatto.com:9000/$arch\n\n\[core\]|' /etc/pacman.conf

# Bootstrap pacman-key
pacman-key --init && pacman-key --populate archlinux

# Update all packages now
pacman -Syu --noconfirm

# Add openssh
pacman -S openssh --noconfirm
systemctl enable --now sshd

# Edit /etc/ssh/sshd_config to add "PermitRootLogin yes"
sudo nano /etc/ssh/sshd_config 
sudo systemctl restart sshd

# Install just 2 packages for the next actions
pacman -S wget sudo git --noconfirm

# create user astro with home, add it to wheel
useradd -G wheel -m astronaut
echo "astronaut:astro" | chpasswd

# Pull the brain repo, this will be used for scripting out the final image
su astronaut -c "git clone https://github.com/MattBlack85/astroarch.git /home/astronaut/.astroarch"

# Uncomment en_US UTF8 and generate locale files
sed -i -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

pacman -Syu base-devel pipewire-jack gnu-free-fonts pipewire-media-session \
        zsh plasma-desktop sddm networkmanager xf86-video-dummy \
	network-manager-applet networkmanager-qt chromium xorg alacritty \
	gpsd breeze-icons hicolor-icon-theme knewstuff \
	knotifyconfig kplotting qt5-datavis3d qt5-quickcontrols \
	qt5-websockets qtkeychain stellarsolver xf86-video-fbdev \
	xplanet plasma-nm dhcp dnsmasq x11vnc gedit plasma-systemmonitor \
	dolphin uboot-tools usbutils cloud-guest-utils samba dhcpcd paru --noconfirm --ask 4
	
# login as other user
echo "now acces as not root user"
exit

# Add AUR packages
su astronaut -c paru -S websockify novnc astrometry.net gsc kstars phd2 \
indi-3rdparty-libs indi-3rdparty-drivers --noconfirm --ask 4

# Allow wheelers to sudo without password to install packages
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# Add astronaut to uucp for serial device ownership
usermod -aG uucp astronaut

# Run now the build script
bash /home/astronaut/.astroarch/build.sh
