#!/bin/sh

setup_brave_browser(){
  # https://brave.com/linux
  sudo dnf -y install dnf-plugins-core

  sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
  sudo dnf -y install brave-browser
}

setup_vscode(){
  # https://code.visualstudio.com/docs/setup/linux#_rhel-fedora-and-centos-based-distributions

  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

  dnf check-update
  sudo dnf -y install code # or code-insiders
}

download_bins(){
  BIN_PATH=${HOME}/bin
  . <(curl -Ls https://raw.githubusercontent.com/redhat-na-ssa/demo-ai-gitops-catalog/refs/heads/main/scripts/library/bin.sh)
  bin_check rclone
  bin_check restic

  rclone completion bash - | sudo tee /etc/profile.d/rclone.sh
  restic generate --bash-completion - | sudo tee /etc/profile.d/restic.sh
  
  PATH=${HOME}/bin:${PATH}
  export PATH
}

update_fedora(){
  sudo dnf -y upgrade --refresh
}

setup_no_password_sudo(){
  # echo "${USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/"${USER}"
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/wheel
}

setup_flatpak_software(){
  [ -e fp-packages.txt ] || return 1
  flatpak -y install flathub $(cat fp-packages.txt)
}

setup_dnf_software(){
  [ -e dnf-packages.txt ] || return 1
  sudo dnf -y install $(grep -v ^group dnf-packages.txt)
  sudo dnf -y group install $(sed -n '/^group/ s/^group//p' dnf-packages.txt)
}

setup_display_link(){
  sudo dnf -y install https://github.com/displaylink-rpm/displaylink-rpm/releases/download/v6.1.1-2/fedora-42-displaylink-1.14.11-1.github_evdi.x86_64.rpm
}

setup_user(){
  sudo usermod -a -G libvirt,disk,cdrom,floppy,kvm,users,dialout "${USER}"
}

setup_luks(){
  sudo clevis luks bind -d /dev/nvme0n1p3 -s1 tpm2 '{"pcr_ids":"0"}'
  sudo systemd-analyze pcrs | sudo tee /root/pcrs
  sudo dracut --regenerate-all --force
}

setup_dconf(){
  [ -e dconf-dump ] || return 1
  dconf load / < dconf-dump

  # fix terminal transparency
  TERM_UUID=$(dconf read /org/gnome/Ptyxis/default-profile-uuid | sed "s@'@@g")
  dconf write "/org/gnome/Ptyxis/Profiles/${TERM_UUID}/opacity" 0.9375


cat << EOF | sudo tee /etc/dconf/db/local.d/10-power
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-timeout=0
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-timeout=900
sleep-inactive-battery-type='suspend'
EOF

cat << EOF | sudo tee /etc/dconf/db/local.d/20-session
[org/gnome/desktop/session]
idle-delay=uint32 0
EOF

cat << EOF | sudo tee /etc/dconf/db/local.d/00-media-automount
[org/gnome/desktop/media-handling]
automount=false
automount-open=false
autorun-never=true
EOF

}

setup_gnome_extensions(){
  python -m venv venv
  . venv/bin/activate

  pip install -U pip
  pip install gnome-extensions-cli

  gnome-extensions-cli install $(cat g-extensions.txt)
  gnome-extensions-cli enable $(cat g-extensions.txt)
  gnome-extensions-cli update

  deactivate
  rm -rf venv
}

setup_obs(){
  mkdir -p ~/.config/obs-studio/plugins
}

tweaks(){
  # fix hidraw access
  echo 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/99-hidraw-permissions.rules
  sudo udevadm control --reload-rules && sudo udevadm trigger

  # fingerprint reader enable
  # https://www.bentasker.co.uk/posts/documentation/linux/enabling-fingerprint-authentication-on-linux.html
  sudo authselect enable-feature with-fingerprint
  sudo authselect apply-changes

}

download_printer_driver(){
  echo "https://in.canon/en/support/0100924010"
}

main(){
  echo "Starting OS configuration..."

  setup_dnf_software
  setup_flatpak_software
  setup_vscode
  update_fedora 

  setup_dconf
  setup_display_link
  setup_gnome_extensions
  setup_luks
  setup_no_password_sudo
  setup_user
  tweaks

  download_printer_driver
  # setup_obs

  printf " Complete"
}

main
