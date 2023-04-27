#!/bin/sh

# Colors :
GREEN='\033[0;32m' # Green
BLUE='\033[1;36m'  # Blue
RED='\033[0;31m'   # Red
NC='\033[0m'       # No Color

SEPARATOR="echo"""

# TODO: Option to have a encrypted Installation
# TODO: Option to have Multiple Users

### Part I ###

# Intro
intro() {
  clear
  echo -e "${BLUE}Arch Installer${NC}"
  sleep 1
  $SEPARATOR
}

check_uefi() {
  # Checking if the computer supports uefi
  DIRECTORY_UEFI="/sys/firmware/efi/efivars/"
  if [ -d $DIRECTORY_UEFI ]; then
    echo -e "${GREEN}This Computer Supports UEFI${NC}"
    $SEPARATOR
  else
    echo -e "${RED}This Computer Doesn't Support UEFI${NC}"
    echo -e "${RED}This Script Only Works With UEFI Systems${NC}"
    exit 0
  fi
}

fzf_pacman_key() {
  pacman-key --init
  pacman -Sy --needed --noconfirm fzf
  clear
}

kb_time() {
  # Keyboard and time
  timedatectl set-ntp true
  kb_layout=$(find /usr/share/kbd/keymaps/ -type f -printf "%f\n" | sort -V | sed 's/.map.gz//g' | fzf --header="Choose a Keyboard Layout" || exit 1)
  loadkeys "$kb_layout"
  $SEPARATOR
  echo "$kb_layout is set for your Keyboard Layout"
  sleep 1
  clear
}

partitioning() {
  # Partioning the Drive
  echo -e "${BLUE}Partioning the Drive${NC}"
  lsblk -p
  printf "${BLUE}[+] Enter The Drive : ${NC}"
  read drive
  fdisk $drive
  clear
}

formating() {
  # Formating the Drive
  echo -e "${BLUE}Formating Partitions${NC}"
  lsblk -p
  echo -e "${BLUE}[+] Enter UEFI Partition: ${NC}"
  read uefipart
  mkfs.fat -F32 $uefipart
  read -p "[+] Did you also create Swap partition? [y/n]: " answer
  if [[ $answer == y ]]; then
    echo -e "${BLUE}[+] Enter the Swap partition: ${NC}"
    read swappart
    mkswap $swappart
    sleep 1
    swapon $swappart
  fi
  echo -e "${BLUE}[+] Enter The Linux Partition: ${NC}"
  read linuxpart
  mkfs.ext4 $linuxpart
}

mounting() {
  # Mounting
  mount $linuxpart /mnt
  mount --mkdir $uefipart /mnt/boot/efi
  clear
  lsblk -p
  sleep 3
  clear
}

base_pkgs() {
  # Pacstrap - fstab - arch-chroot
  echo -e "${BLUE}Installing Packages with Pacstrap${NC}"
  $SEPARATOR
  pacstrap -K /mnt base linux linux-firmware linux-headers neovim git fzf
  genfstab -U /mnt >> /mnt/etc/fstab
  clear
}

locale() {
  # Locale, hwclock, hostname
  echo -e "${BLUE}Seting Up the Locale${NC}"
  ln -sf /usr/share/zoneinfo/America/Sao_Paulo /mnt/etc/localtime
  arch-chroot /mnt hwclock --systohc
  echo 'pt_BR.UTF-8 UTF-8' >> /mnt/etc/locale.gen
  arch-chroot /mnt locale-gen
  echo 'LANG=pt_BR.UTF-8' >> /mnt/etc/locale.conf
  echo "KEYMAP=$kb_layout" >> /mnt/etc/vconsole.conf
  echo "$kb_layout is set in /mnt/etc/vconsole.conf"
  sleep 1
  echo -e "${BLUE}[+] Enter The Hostname: ${NC}"
  read host
  echo $host >> /mnt/etc/hostname
  echo "$host is set as the hostname of the computer"
  sleep 1
  clear
}

pacman_conf() {
  # Pacman.conf
  echo -e "${BLUE}Installing Essencial Packages${NC}"
  sed -i "s/#Color/Color/" /mnt/etc/pacman.conf
  sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 5/" /mnt/etc/pacman.conf
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
  arch-chroot /mnt pacman -Sy --needed --noconfirm doas grub os-prober efibootmgr networkmanager libvirt fish xorg xorg-xinit
  $SEPARATOR
  echo -e "${GREEN}Installaling Base-devel Packages minus Sudo${NC}"
  arch-chroot /mnt pacman -Sy --needed --noconfirm archlinux-keyring autoconf automake binutils bison debugedit fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed texinfo which
  echo -e "${GREEN}Installation Done${NC}"
  clear
}

users() {
  # User and Root Password
  echo -e "${BLUE}Root Password${NC}"
  arch-chroot /mnt passwd
  echo -e "${BLUE}Create User${NC}"
  echo -e "${BLUE}[+] User Name: ${NC}"
  read username
  arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage,libvirt -s /bin/fish $username
  echo -e "${BLUE}$username Password${NC}"
  arch-chroot /mnt passwd $username
  echo 'permit keepenv persist :wheel' >> /mnt/etc/doas.conf
  clear
}

grub_uefi() {
  # Grub with uefi
  echo -e "${BLUE}Setting Up Grub With UEFI${NC}"
  sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /mnt/etc/default/grub
  arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

services() {
  # Enbling Services
  echo -e "${BLUE}Enabling Services (NetworkManager, bluetooth, libvirtd)${NC}"
  arch-chroot /mnt systemctl enable NetworkManager
  arch-chroot /mnt systemctl enable bluetooth.service
  arch-chroot /mnt systemctl enable libvirtd
}

echo_reboot() {
  # Message
  echo -e "${BLUE}Clone the repo again and run sh arch_installer.sh 2 (after reboot)${NC}"
  $SEPARATOR
  
  # Reboot
  echo -e "${GREEN}Reboot${NC}"
}

### Part II ###

aur_helper() {
  echo -e "${BLUE}Installing Paru AUR Helper${NC}"
  git clone https://aur.archlinux.org/paru-bin.git
  cd paru-bin
  makepkg -si
  cd ..
  rm paru-bin -rf
  sleep 1

  # Paru.conf
  doas sed -i 's/\#\[bin\]/\[bin\]/' /etc/paru.conf
  doas sed -i "s|#Sudo = doas|Sudo = /bin/doas|" /etc/paru.conf
  doas sed -i "s|#FileManager = vifm|FileManager = lf|" /etc/paru.conf
  doas sed -i 's/\#BottomUp/BottomUp/' /etc/paru.conf
  doas sed -i "s/#RemoveMake/RemoveMake/" /etc/paru.conf
  doas sed -i "s/#CleanAfter/CleanAfter/" /etc/paru.conf
}

x11_keyboard() {
  # Set X11 keyboard
  doas localectl set-x11-keymap br
}

xinitrc() {
  # Xinitrc
  head -n -5 /etc/X11/xinit/xinitrc >> ~/.xinitrc
  echo "exec awesome" >> ~/.xinitrc
  clear
  
  echo -e "${GREEN}Installer Finished${NC}"
}

if [ "$1" = 1 ]; then
  intro
  check_uefi
  fzf_pacman_key
  kb_time
  partitioning
  formating
  mounting
  base_pkgs
  locale
  pacman_conf
  users
  grub_uefi
  services
  echo_reboot
elif [ "$1" = 2 ]; then
  aur_helper
  x11_keyboard
  xinitrc
else
  echo -e "${BLUE}This Script Only Works with Arguments.${NC}"
  echo -e "${GREEN}sh arch_installer 1.${NC}"
  echo -e "${GREEN}sh arch_installer 2.${NC}"
fi
