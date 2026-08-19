#!/usr/bin/env bash
# Desktop (FIXEJVZ, 192.168.0.109) setup: Tdarr CPU node + NFS + rffmpeg worker.
# Run with: sudo bash setup.sh     (must be run as root; drops to jvz where needed)
set -euo pipefail

PI=192.168.0.106
USER_NAME=jvz
SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "### 1/4  packages"
pacman -S --needed --noconfirm nfs-utils jellyfin-ffmpeg

echo "### 2/4  NFS mounts"
mkdir -p /data/media /transcode /config
if ! grep -q 'jftranscode' /etc/fstab; then
  cat >> /etc/fstab <<'EOF'

# --- Jellyfin remote transcode (rffmpeg worker) + Tdarr node ---------------
# NFS shares from Pi (rpi, 192.168.0.106). Paths MUST match the Jellyfin
# container's paths exactly (rffmpeg requirement). Full plan + rationale:
#   pi:/srv/jellyfin/REMOTE_TRANSCODE_PLAN.md
192.168.0.106:/mnt/raid0/rpismb/Media  /data/media  nfs  ro,vers=4.2,_netdev,x-systemd.automount,noauto  0 0
192.168.0.106:/mnt/raid0/jftranscode   /transcode   nfs  rw,vers=4.2,_netdev,x-systemd.automount,noauto  0 0
192.168.0.106:/srv/jellyfin/config     /config      nfs  ro,vers=4.2,_netdev,x-systemd.automount,noauto,actimeo=1  0 0
# ---------------------------------------------------------------------------
EOF
fi
systemctl daemon-reload
mount /data/media; mount /transcode; mount /config
touch /transcode/.probe && rm /transcode/.probe && echo "  /transcode writable OK"

echo "### 3/4  sshd + rffmpeg key + firewall"
systemctl enable --now sshd
install -d -o "$USER_NAME" -g "$USER_NAME" -m 700 "/home/$USER_NAME/.ssh"
KEY='from="192.168.0.106",no-agent-forwarding,no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMFjuWBhw1tJQo/Zk3WFYM6YVfR3C8clncfv1ZU8zUsS rffmpeg-jellyfin@rpi'
touch "/home/$USER_NAME/.ssh/authorized_keys"
grep -qF 'rffmpeg-jellyfin@rpi' "/home/$USER_NAME/.ssh/authorized_keys" || \
  echo "$KEY" >> "/home/$USER_NAME/.ssh/authorized_keys"
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"
ufw allow from $PI to any port 22   proto tcp comment 'rffmpeg SSH from Pi'
ufw allow from $PI to any port 8267 proto tcp comment 'Tdarr server -> node'

echo "### 4/4  Tdarr node stack"
mkdir -p /srv/tdarr-node/configs /srv/tdarr-node/logs /srv/tdarr-node/temp
chown -R 1000:1000 /srv/tdarr-node
cp "$SCRATCH/tdarr-node-compose.yaml" /srv/tdarr-node/compose.yaml
docker compose -f /srv/tdarr-node/compose.yaml up -d

echo
echo "DONE. Verify with the block 5 commands."
