# Vultr Phishing Investigation Tool

An automated Bash utility for temporary, dual-stack (IPv4/IPv6) infrastructure for phishing investigations. (tested in Kali)

## 🛡️ Purpose & OPSEC
This tool automates the creation of a secure proxy by:
1. Deploying a VPS on Vultr in one of 20+ global regions.
2. Enabling **IPv6** to bypass sophisticated phishing kits that block IPv4 datacenter traffic.
3. Establishing an SSH SOCKS5 tunnel with an automated "Keep-Alive" monitor.

---

## ⚙️ Prerequisites
1. **Vultr Account & API Key**: Create an API key in your dashboard. **CRITICAL:** Add your corporate/home IP to the Vultr API Access Control list, or the script will be blocked.
2. **Vultr CLI**: Ensure `vultr-cli` is installed.
3. **Required Packages**: `jq`, `curl`, `netcat-openbsd`.
4. **SSH Key**: Generate an SSH key (`ssh-keygen`), add a passphrase, and upload the public key to your Vultr account.

---

## 🚀 Installation & Setup

1. **Clone the repository:**
   * `git clone https://github.com/malias4/Vultr-Phishing-Investigation-Tool.git`
   * `cd Vultr-Phishing-Investigation-Tool`

2. **Move the script to your home directory:**
   * `cp investigator.sh ~/investigator.sh`

3. **Create your configuration file in your home directory (`~/.env`):**
   Create a file named `.env` in your `~/` directory and add the following:

   * `export VULTR_API_KEY="YOUR_API_KEY_HERE"`
   * `export SSH_KEY_NAME="Name_of_Key_on_Vultr_Dashboard"`
   * `export SSH_KEY_PATH="$HOME/.ssh/your_private_key_name"`

4. **Make it global:** Add it to your `.zshrc` or `.bashrc` so you can use the tool from anywhere.
   * `echo 'source ~/investigator.sh' >> ~/.zshrc`
   * `source ~/.zshrc`

---

## 🦊 Browser Configuration (Mandatory)
For the tunnel to work, you must force your browser to use the SOCKS5 proxy and route DNS through it.

1. Install the **FoxyProxy** extension in Firefox.
2. Add a new proxy with the following settings:
   * **Title**: Vultr Investigation
   * **Type**: SOCKS5
   * **Hostname/IP**: 127.0.0.1
   * **Port**: 1080
   * **Proxy DNS**: ON (Toggle switch must be active)
3. Install a **User-Agent Switcher** extension. Mimic iOS/Android, or Windows/Chrome.

---

## 📖 Usage Guide

* `help-investigation` Help menu. Shows all commands.

* `locations-investigation` Lists all supported global region codes.

* `start-investigation [code]` Deploys a server (e.g., `start-investigation de` for Germany). It will prompt for your SSH passphrase once per session.

* `watch-investigation` Starts the Keep-Alive monitor. If your VM goes to sleep, this will automatically detect the dropped tunnel and reconnect it when you wake the machine.

* `status-investigation` Shows your active Vultr IP and location.

* `stop-investigation` Destroys the server. **Always run this when your investigation is complete. Don't buy Bezos another yacht to park out on the pier, save that sixty bucks instead to buy your peers a 🍺**
