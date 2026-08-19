# Desktop (FIXEJVZ, 192.168.0.109) — media worker for the Pi

Rebuilt 2026-07-27. This machine is a **worker** for two independent services that both
live on the Pi (`rpi5.local` / 192.168.0.106). Nothing here is auto-tracked by omarchy —
if you reinstall again, this file plus `media-worker-setup.sh` (same dir) is the recovery kit.

**Source of truth for the Jellyfin half:** `pi:/srv/jellyfin/REMOTE_TRANSCODE_PLAN.md`.

| Workload | Engine | Reached how |
|---|---|---|
| Jellyfin live transcode | RTX 3060 **NVENC** | Pi's Jellyfin container SSHes in via `rffmpeg`, runs bare-metal `/usr/lib/jellyfin-ffmpeg/ffmpeg` |
| Tdarr library encode | **CPU / SVT-AV1** (5900X) | `tdarr-node` container dials the Pi's Tdarr server on 8266 |

The GPU is deliberately *not* given to the Tdarr container — it stays free for Jellyfin's
on-the-fly transcodes. Tdarr's encoder probe correctly reports `libsvtav1-true-true` and
`h264_nvenc-true-false`.

## Packages
`pacman -S --needed nfs-utils jellyfin-ffmpeg`
(`jellyfin-ffmpeg`, not system `ffmpeg` — the latter lacks `tonemap_cuda`.)

## NFS mounts — /etc/fstab
Paths **must** match the Jellyfin *container's* paths exactly; rffmpeg bakes absolute
paths into the ffmpeg command line it replays here.

```
192.168.0.106:/mnt/raid0/rpismb/Media  /data/media  nfs  ro,vers=4.2,_netdev,x-systemd.automount,noauto  0 0
192.168.0.106:/mnt/raid0/jftranscode   /transcode   nfs  rw,vers=4.2,_netdev,x-systemd.automount,noauto  0 0
192.168.0.106:/srv/jellyfin/config     /config      nfs  ro,vers=4.2,_netdev,x-systemd.automount,noauto,actimeo=1  0 0
```

`/data/media` is **ro** here on purpose — Jellyfin's ffmpeg only ever reads. Tdarr needs
*write* access (it replaces the original file after encoding), so it gets its own separate
**rw** mount as a Docker NFS volume rather than widening this one.

## rffmpeg SSH access
- `sshd` enabled. The Pi's key is in `~/.ssh/authorized_keys`, pinned `from="192.168.0.106"`.
- ufw: allow 22 and 8267, both scoped to 192.168.0.106.
- **Gotcha that will bite you on the next rebuild:** the Pi pins this machine's SSH *host*
  keys in `/srv/jellyfin/config/rffmpeg/.ssh/known_hosts`. A rebuilt desktop gets new host
  keys and rffmpeg fails hard — `StrictHostKeyChecking=accept-new` only accepts *unknown*
  hosts, not *changed* ones. Fix on the Pi:
  ```
  KH=/srv/jellyfin/config/rffmpeg/.ssh/known_hosts
  sudo cp -a $KH $KH.bak.$(date +%s)
  sudo ssh-keygen -f $KH -R 192.168.0.109
  ssh-keyscan -t rsa,ed25519 192.168.0.109 | sudo tee -a $KH >/dev/null
  sudo chown 1000:1000 $KH
  ```

## Tdarr node
Stack at `/srv/tdarr-node/compose.yaml` (data dirs `configs/ logs/ temp/`, owned 1000:1000).

- Image tag is **pinned to the server's version** (currently `2.81.01`). Tdarr refuses
  mismatched node/server versions — bump this together with the Pi's server.
- `nodeName=desktop-5900x` must stay: the server DB holds this node's worker limits and
  flow assignments under that name (nodeID `TsXQPZsUa`). Renaming orphans all of it.
- `/temp` is local NVMe, *not* NFS — the transcode cache is hammered and must not cross
  the 1 GbE link. Each node owns its cache; the server never reads it.

## Boot behaviour
`docker.service` must be **enabled**, not just `docker.socket`. Socket activation alone
does not restore `restart: unless-stopped` containers at boot, so the Tdarr node would
never come up on this on-demand desktop.

## Verify the whole chain
```bash
findmnt -t nfs4                                        # 3 host mounts + docker volume
docker exec tdarr-node ls /media                       # Films Livres Series Tmp
curl -s http://192.168.0.106:8265/api/v2/get-nodes     # node online, desktop-5900x
# from the Pi — proves remote NVENC:
ssh rpi5.local 'sudo docker exec jellyfin rffmpeg status'
```
