#!/bin/bash

# Colors :
GREEN='\033[0;32m' # Green
BLUE='\033[1;36m'  # Blue
RED='\033[0;31m'   # Red
NC='\033[0m'       # No Color

ENABLED_SYSTEMD="NetworkManager libvirtd sshd bluetooth"
SEPARATOR="echo"""

# TODO: Option to have a encrypted Installation
# TODO: Add a fzf prompt to choose localtime

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
	echo -e "${BLUE}[+] Enter The Drive : ${NC}"
	read drive
	fdisk "$drive"
	clear
}

formating() {
	# Formating the Drive
	echo -e "${BLUE}Formating Partitions${NC}"
	lsblk -p
	echo -e "${BLUE}[+] Enter UEFI Partition: ${NC}"
	read uefipart
	mkfs.fat -F32 "$uefipart"
	read -p "[+] Did you also create Swap partition? [y/n]: " answer
	if [[ $answer == y ]]; then
		echo -e "${BLUE}[+] Enter the Swap partition: ${NC}"
		read swappart
		mkswap "$swappart"
		sleep 1
		swapon "$swappart"
	fi
	echo -e "${BLUE}[+] Enter The Linux Partition: ${NC}"
	read linuxpart
	mkfs.ext4 "$linuxpart"
}

mounting() {
	# Mounting
	mount "$linuxpart" /mnt
	mount --mkdir "$uefipart" /mnt/boot/efi
	clear
	lsblk -p
	sleep 3
	clear
}

base_pkgs() {
	# Pacstrap - fstab - arch-chroot
	echo -e "${BLUE}Installing Packages with Pacstrap${NC}"
	$SEPARATOR
	pacstrap -K /mnt base linux linux-firmware linux-headers
	genfstab -U /mnt >>/mnt/etc/fstab
	clear
}

locale() {
	# Locale, hwclock, hostname
	echo -e "${BLUE}Seting Up the Locale${NC}"
	ln -sf /usr/share/zoneinfo/America/Sao_Paulo /mnt/etc/localtime
	arch-chroot /mnt hwclock --systohc
  LOCALE_GEN=$(grep '[A-Za-z]\.UTF-8' /usr/share/i18n/SUPPORTED | fzf --header="Choose a Locale" || exit 1)
	echo "$LOCALE_GEN" >>/mnt/etc/locale.gen
	arch-chroot /mnt locale-gen
	$SEPARATOR
  LOCALE_CONF=$(echo "$LOCALE_GEN" | awk -F ' ' '{ print $1 }')
	echo "LANG=$LOCALE_CONF" >>/mnt/etc/locale.conf
	echo "KEYMAP=$kb_layout" >>/mnt/etc/vconsole.conf
	echo "$kb_layout is set in /mnt/etc/vconsole.conf"
	sleep 1
	echo -e "${BLUE}[+] Enter The Hostname: ${NC}"
	read host
	echo "$host" >>/mnt/etc/hostname
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
	arch-chroot /mnt pacman -Sy --needed --noconfirm doas grub os-prober efibootmgr networkmanager libvirt fish openssh neovim git fzf
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
	arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage,libvirt -s /bin/fish "$username"
	echo -e "${BLUE}$username Password${NC}"
	arch-chroot /mnt passwd "$username"
	echo 'permit keepenv persist :wheel' >>/mnt/etc/doas.conf
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
	echo -e "${BLUE}Enabling Services${NC}"

  for system in $ENABLED_SYSTEMD
  do
    arch-chroot /mnt systemctl enable "$system"
  done
}

x11() {
	"$SEPARATOR"
	read -p "[+] Do you want to install a display server (xorg)? [y/n]: " answer_x11
	if [[ $answer_x11 == y ]]; then
		arch-chroot /mnt pacman -Sy xorg xorg-xinit

		# Set X11 keyboard
		arch-chroot /mnt localectl set-keymap "$kb_layout"

		# Xinitrc
		head -n -5 /mnt/etc/X11/xinit/xinitrc >>/mnt/home/$username/.xinitrc
		echo "exec awesome" >>/mnt/home/$username/.xinitrc
		clear
	fi
}

aur_helper() {
	"$SEPARATOR"
	read -p "[+] Do you want to install a aur helper (paru)? [y/n]: " answer_paru
	if [[ $answer_paru == y ]]; then
	  arch-chroot /mnt pacman -Sy --needed --noconfirm lf
		# Install Paru
		echo -e "${GREEN}Installing Aur Helper Paru${NC}"
		arch-chroot -u "$username" /mnt sh -c "
  cd /home/$username;
  git clone https://aur.archlinux.org/paru-bin.git;
  cd paru-bin;
  makepkg -si;
  cd ..;
  rm paru-bin -rf;
  "

		# Paru.conf
		sed -i 's/\#\[bin\]/\[bin\]/' /mnt/etc/paru.conf
		sed -i "s|#Sudo = doas|Sudo = /bin/doas|" /mnt/etc/paru.conf
		sed -i "s|#FileManager = vifm|FileManager = lf|" /mnt/etc/paru.conf
		sed -i 's/\#BottomUp/BottomUp/' /mnt/etc/paru.conf
		sed -i "s/#RemoveMake/RemoveMake/" /mnt/etc/paru.conf
		sed -i "s/#CleanAfter/CleanAfter/" /mnt/etc/paru.conf
		echo -e "${GREEN}Installation Finished${NC}"
	fi
}

add_user() {
	"$SEPARATOR"
	read -p "[+] Do you want to add more users to the system? [y/n]: " answer_add_user
	if [[ $answer_add_user == y ]]; then

		if [ "$(id -u)" -eq 0 ]; then
			read -p "How many user(s) you wanna add? " answer_users

			i=$answer_users

			until [ "$i" -eq 0 ]; do
				echo "Users to be added: $i"
				echo -e "${BLUE}Create User${NC}"
				echo -e "${BLUE}[+] User Name: ${NC}"
				read username
				arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage,libvirt -s /bin/fish $username
				echo -e "${BLUE}$username Password${NC}"
				arch-chroot /mnt passwd "$username"
				((--i))
			done
		else
			echo "Run as root"
		fi
	fi
}

finish() {
	"$SEPARATOR"
	echo -e "${GREEN}Installer Finished${NC}"
	echo -e "${BLUE}Now rebooting the machine.${NC}"
}

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
x11
aur_helper
add_user
finish
reboot
