export PATH=/usr/share/GSC/bin:$HOME/bin:/usr/local/bin:$PATH
export ZSH="$HOME/.oh-my-zsh"
export LC_CTYPE=en_US.UTF-8

ZSH_THEME="af-magic"

zstyle ':omz:update' mode disabled

ENABLE_CORRECTION="false"
HIST_STAMPS="yyyy-mm-dd"

plugins=(git archlinux)

source $ZSH/oh-my-zsh.sh

EDITOR=nano
INDI_ROLLBACK_VERSION=2.0.4-1
KSTARS_ROLLBACK_VERSION=3.6.7-2

# Alias section
alias update-astromonitor='wget -O - https://raw.githubusercontent.com/MattBlack85/astro_monitor/main/install.sh | sh'
alias astro-rollback-full='astro-rollback-indi && astro-rollback-kstars'

# Run aa_motd.sh
bash /home/astronaut/.astroarch/scripts/aa_motd.sh

function astro-rollback-indi()
{
    setopt localoptions rmstarsilent
    mkdir -p ~/.rollback
    cd ~/.rollback
    wget -O indi-3rdparty-drivers-${INDI_ROLLBACK_VERSION}-aarch64.pkg.tar.xz http://astromatto.com:9000/aarch64/indi-3rdparty-drivers-${INDI_ROLLBACK_VERSION}-aarch64.pkg.tar.xz
    wget -O libindi-${INDI_ROLLBACK_VERSION}-aarch64.pkg.tar.xz http://astromatto.com:9000/aarch64/libindi-${INDI_ROLLBACK_VERSION}-aarch64.pkg.tar.xz
    wget -O indi-3rdparty-libs-${INDI_ROLLBACK_VERSION}-aarch64.pkg.tar.xz http://astromatto.com:9000/aarch64/indi-3rdparty-libs-${INDI_ROLLBACK_VERSION}-aarch64.pkg.tar.xz
    sudo pacman -U libindi* indi* --noconfirm
    cd - > /dev/null 2>&1
    rm -rf ~/.rollback/*
}

function astro-rollback-kstars()
{
    setopt localoptions rmstarsilent
    mkdir -p ~/.rollback
    cd ~/.rollback
    wget -O kstars-${KSTARS_ROLLBACK_VERSION}-aarch64.pkg.tar.xz http://astromatto.com:9000/aarch64/kstars-${KSTARS_ROLLBACK_VERSION}-aarch64.pkg.tar.xz
    sudo pacman -U kstars* --noconfirm
    cd - > /dev/null 2>&1
    rm -rf ~/.rollback/*
}

function update-astroarch()
{
    # Store actual version
    OLD_VER=$(cat /home/$USER/.astroarch.version)

    # Checkout latest changes from git
    cd /home/$USER/.astroarch
    git pull origin main
    cd - > /dev/null 2>&1

    NEW_VER=$(cat /home/$USER/.astroarch/configs/.astroarch.version)

    if [ $OLD_VER != $NEW_VER ]; then
	zsh /home/$USER/.astroarch/scripts/$NEW_VER.sh
    fi;

    # Update always keyring first, than all of the other packages
    sudo pacman -Sy
    sudo pacman -S archlinux-keyring --noconfirm

    # Now upgrade all system packages
    sudo pacman -Syu --noconfirm
}
