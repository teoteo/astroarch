# Install yay
cd /home/astronaut
su astronaut -c "git clone https://aur.archlinux.org/yay.git"
cd yay/
su astronaut -c "makepkg -s"
pacman -U yay*.tar.xz --noconfirm
cd .. && rm -rf yay/

# install oh-my-zsh and set the default shell to zsh
chsh -s /usr/bin/zsh astronaut
rm /home/astronaut/.bash*
cd /home/astronaut
ZSH=/home/astronaut/.oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chown astronaut:astronaut .oh-my-zsh/
# copy a zsh config for astronaut
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc

su astronaut -c "yay -S --noremovemake --nodiffmenu --answerclean 4 gsc"
su astronaut -c "yay -S novnc"

# prepare folder for user services
su astronaut -c "mkdir -p /home/astronaut/.config/systemd/user/default.target.wants"

# make a dir to store sddm config
mkdir /etc/sddm.conf.d

# Start NetworkManager and sleep to create the hotspot
systemctl start NetworkManager
sleep 5

# Create the hotspot and set autoconnect to true
nmcli device wifi hotspot ifname wlan0 ssid AstroArch password "astronomy"
sed -i 's/autoconnect=false/autoconnect=true/g' /etc/NetworkManager/system-connections/Hotspot.nmconnlection

# Create Xauthority for x11vnc
su astronaut -c "touch /home/astronaut/.Xauthority"

# Remove eventually existing systemd configs we are going to substitute
rm /usr/lib/systemd/system/novnc.service

# Symlink now files
ln -s /home/astronaut/.astroarch/systemd/autologin.conf /etc/sddm.conf.d/autologin.conf
ln -s /home/astronaut/.astroarch/systemd/novnc.service /usr/lib/systemd/system/novnc.service
ln -s /home/astronaut/.astroarch/systemd/x11vnc.service /home/astronaut/.config/systemd/user/default.target.wants/x11vnc.service
ln -s /home/astronaut/.astroarch/systemd/x11vnc.service /home/astronaut/.config/systemd/user
ln -s /home/astronaut/.astroarch/configs/20-headless.conf /usr/share/X11/xorg.conf.d/20-headless.conf

# Enable now all services
systemctl enable sddm.service novnc.service dhcpcd.service NetworkManager.service avahi-daemon.service

# Take sudoers to the original state
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Link wallpaper
ln -s /home/astronaut/.astroarch/wallpapers/bubble.jpg /home/astronaut/Pictures

# config hostnames
echo "astroarch" > /etc/hostname
echo "127.0.0.1          localhost" >> /etc/hosts
echo "127.0.1.1          astroarch" >> /etc/hosts

# Reboot and enjoy now
reboot
