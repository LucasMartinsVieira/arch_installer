#!/bin/sh

# Colors :
GREEN='\033[0;32m' # Green
BLUE='\033[1;36m'  # Blue
RED='\033[0;31m'   # Red
NC='\033[0m'       # No Color

SEPARATOR="echo"""

if [ "$1" = 1 ]; then
####################
###### Part I ######
####################

clear

# Intro
echo -e "${BLUE}Arch Installer${NC}"
sleep 1
$SEPARATOR

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

# Keyboard and time
echo -e "${BLUE}[+] Enter your Keyboard Layout: ${NC}"
timedatectl set-ntp true
read kb_layout
loadkeys $kb_layout
echo "$kb_layout is set for your Keyboard Layout"
sleep 1
clear

# Partioning the Drive
echo -e "${BLUE}Partioning the Drive${NC}"
lsblk -p
printf "${BLUE}[+] Enter The Drive : ${NC}"
read drive
fdisk $drive
clear

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

# Mounting
mount $linuxpart /mnt
mount --mkdir $uefipart /mnt/boot/efi
clear
lsblk -p
sleep 3
clear

# Pacstrap - fstab - arch-chroot
echo -e "${BLUE}Installing Packages with Pacstrap${NC}"
$SEPARATOR
pacstrap -K /mnt base linux linux-firmware linux-headers neovim git
genfstab -U /mnt >> /mnt/etc/fstab

# Message
echo -e "${BLUE}Clone the repo again and run part_2${NC}"
$SEPARATOR
# arch-chroot
arch-chroot /mnt

elif [ "$1" = 2 ]; then
###################
##### Part II #####
###################

# Locale, hwclock, hostname
echo -e "${BLUE}Seting Up the Locale${NC}"
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
echo 'pt_BR.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG=pt_BR.UTF-8' >> /etc/locale.conf
echo -e "${BLUE}[+] Enter your Keyboard Layout: ${NC}"
read kb_layout
echo "KEYMAP=$kb_layout" >> /etc/vconsole.conf
echo "$kb_layout is set in /etc/vconsole.conf"
sleep 1
echo -e "${BLUE}[+] Enter The Hostname: ${NC}"
read host
echo $host >> /etc/hostname
echo "127.0.0.1       localhost" >> /etc/hosts
echo "::1             localhost" >> /etc/hosts
echo "$host is set as the hostname of the computer"
sleep 1
clear

# Pacman.conf
echo -e "${BLUE}Installing Essencial Packages${NC}"
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 5/" /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --needed --noconfirm doas grub os-prober efibootmgr networkmanager libvirt fish xorg xorg-xinit
$SEPARATOR
echo -e "${GREEN}Installaling Base-devel Packages minus Sudo${NC}"
pacman -Sy --needed archlinux-keyring autoconf automake binutils bison debugedit fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed texinfo which
echo -e "${GREEN}Installation Done${NC}"
clear

# User and Root Password
echo -e "${BLUE}Root Password${NC}"
passwd
echo -e "${BLUE}Create User${NC}"
echo -e "${BLUE}[+] User Name: ${NC}"
read username
useradd -m -G wheel,audio,video,optical,storage,libvirt -s /bin/fish $username
echo -e "${BLUE}$username Password${NC}"
passwd $username
echo 'permit keepenv persist :wheel' >> /etc/doas.conf
clear

# Grub with uefi
echo -e "${BLUE}Setting Up Grub With UEFI${NC}"
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Enbling Services
echo -e "${BLUE}Enabling Services${NC}"
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable libvirtd

# Message
echo -e "${BLUE}Clone the repo again and run part_3 (after reboot)${NC}"
$SEPARATOR

# Reboot
echo -e "${GREEN}Press 'Control + d' and Reboot${NC}"

elif [ "$1" = 3 ]; then
####################
##### Part III #####
####################

echo -e "${BLUE}Installing Paru AUR Helper${NC}"
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin
makepkg -si
cd ..
rm paru-bin -rf

# Paru.conf
doas sed -i 's/\#\[bin\]/\[bin\]/' /etc/paru.conf
doas sed -i "s|#Sudo = doas|Sudo = /bin/doas|" /etc/paru.conf
doas sed -i "s|#FileManager = vifm|FileManager = lf|" /etc/paru.conf
doas sed -i 's/\#BottomUp/BottomUp/' /etc/paru.conf
doas sed -i "s/#RemoveMake/RemoveMake/" /etc/paru.conf
doas sed -i "s/#CleanAfter/CleanAfter/" /etc/paru.conf

# Set X11 keyboard
doas localectl set-x11-keymap br

# Xinitrc
cp /etc/X11/xinit/xinitrc ~/.xinitrc
nvim ~/.xinitrc

echo -e "${GREEN}Installer Finished${NC}"

else
  echo -e "${BLUE}This Script Only Works with Arguments.${NC}"
  echo -e "${GREEN}sh arch_installer 1.${NC}"
  echo -e "${GREEN}sh arch_installer 2.${NC}"
  echo -e "${GREEN}sh arch_installer 3.${NC}"
fi