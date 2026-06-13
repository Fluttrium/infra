#!/bin/bash
# Альтернатива cloud-init.yaml для провайдеров, где поле «скрипт при загрузке»
# принимает обычный bash (а не #cloud-config). Выполняется при первом старте под root.
#
# ⚠️ Замени PUBKEY на содержимое своего публичного ключа: cat ~/.ssh/fluttrium_vps.pub
set -euo pipefail

PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...ВСТАВЬ_СВОЙ_ПУБЛИЧНЫЙ_КЛЮЧ... roman@fluttrium"

# --- пользователь deploy + ключ ---
id deploy &>/dev/null || adduser --disabled-password --gecos "" deploy
usermod -aG sudo deploy
echo "deploy ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
echo "$PUBKEY" > /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys

# --- пакеты (Docker из репозиториев дистрибутива — надёжно из РФ, без CDN docker.com) ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
apt-get install -y ca-certificates curl ufw fail2ban unattended-upgrades docker.io docker-compose-v2

# --- swap 2 ГБ ---
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- Docker (поставлен из apt выше): включить и добавить deploy в группу ---
usermod -aG docker deploy
systemctl enable --now docker

# --- hardening sshd ---
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# --- фаервол ---
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# --- авто-обновления безопасности ---
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

systemctl restart ssh || systemctl restart sshd
echo "fluttrium server ready. Вход: ssh deploy@<IP>"
