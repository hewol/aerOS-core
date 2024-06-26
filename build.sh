#!/bin/bash

pacman -Q gdm networkmanager network-manager-applet > /dev/null
NOT_INSTALLED=$?

echo "Installing required packages"
sudo pacman -Sy archiso gdm networkmanager network-manager-applet --noconfirm

pacman -Qg gnome > /dev/null
GNOME_NOT_INSTALLED=$?

set -e
clean() {
    echo "Cleaning work directory"
    sudo umount -Rq work || true
    sudo rm -r work

    if [ $NOT_INSTALLED -eq 0 ]; then
        echo "Not removing build packages because GNOME is installed."
    else
        echo "Cleaning required build packages"
        sudo pacman -Rns gdm networkmanager network-manager-applet --noconfirm       
    fi
}

enable_services() {
    create_symlink() {
        source="$1"
        target="$2"
        printf "Creating symlink for %s\n" "$source"
        ln -svf "$source" "archiso/airootfs/etc/systemd/system/$target"
    }
    

    
    create_symlink "/usr/lib/systemd/system/graphical.target" "default.target"
    create_symlink "/usr/lib/systemd/system/gdm.service" "display-manager.service"
    create_symlink "/usr/lib/systemd/system/NetworkManager.service" "multi-user.target.wants/NetworkManager.service"
    create_symlink "/usr/lib/systemd/system/NetworkManager-dispatcher.service" "dbus-org.freedesktop.nm-dispatcher.service"
    create_symlink "/usr/lib/systemd/system/NetworkManager-wait-online.service" "network-online.target.wants/NetworkManager-wait-online.service"
}

install_chaotic_aur() {
    echo "Chaotic AUR is not installed on your system. Do you want to install it? [y/n] "
    read -r install
    
    if [[ ${install:0:1} == "y" || ${install:0:1} == "" ]]; then
        echo "Installing Chaotic AUR"
        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        sudo pacman-key --lsign-key 3056513887B78AEB
        sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        if [ -f /etc/pacman.d/chaotic-mirrorlist ]; then
            echo "Successfully installed Chaotic AUR, continuing with the build."
        else
            echo "Chaotic AUR mirrorlist not found, aborting build."
            rerun=false
        fi
    else
        echo "Chaotic AUR mirrorlist not found, aborting build."
        rerun=false
    fi
}

if [ ! -f /etc/pacman.d/chaotic-mirrorlist ]; then
    install_chaotic_aur
fi

rerun=true
while $rerun; do
    if test -d work; then
        clean
    fi

    enable_services

    if ! sudo mkarchiso -v archiso; then
        set +e
        echo
        echo -n "Build failed, do you want to retry the build? [y/n] "
        read -r retry
        if [[ ${retry:0:1} != "y" ]]; then
            rerun=false
            retcod=1
        else
            :
        fi
    else
        rerun=false
    fi
done

test -d work && clean

if [[ "$retcod" -eq 0 ]]; then
    echo "Building finished successfully."
else
    echo "Building failed."
fi

exit $retcod
