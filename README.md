# Arch Linux Installation Script

![GitHub top language](https://img.shields.io/github/languages/top/lucasmartinsvieira/arch_installer?color=green)
![GitHub last commit](https://img.shields.io/github/last-commit/lucasmartinsvieira/arch_installer?color=green)
![GitHub](https://img.shields.io/github/license/lucasmartinsvieira/arch_installer?color=green)

This is a simple script to install [Arch Linux](https://archlinux.org/) after you have booted in the live environment of Arch Linux.

## Usage

To use the script make sure you have internet connection. If you're using a wireless connection the [`iwd`](https://wiki.archlinux.org/title/Iwd#iwctl) Arch Wiki Article will help you seting up a internet connection in the live environment.

```bash
# With one command (using curl)
bash <(curl -s https://raw.githubusercontent.com/LucasMartinsVieira/arch_installer/main/arch_installer.sh)

# Git Method (make sure you have git installed in the live environment)
git clone https://github.com/lucasmartinsvieira/arch_installer.git
cd arch_installer
bash arch_installer.sh
```

## Options

In the script you'll have the options to: 

- Install Xorg (not an DE or WM);
- Install [`paru`](https://github.com/Morganamilo/paru);
- Add more than one user to the System;

## Notes

- This script setup uses [`doas`](https://github.com/slicer69/doas) instead of [`sudo`](https://github.com/sudo-project/sudo) as a way to give the user root privilege
- This script assumes that you only have one drive
- Only works for UEFI systems 
