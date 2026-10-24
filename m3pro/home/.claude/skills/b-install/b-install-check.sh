#!/bin/bash
# b-install skill helper for System B. Read-only, no sudo.
#   bash b-install-check.sh pre <pkg>...   preview a repo install: full transaction + flags
#   bash b-install-check.sh post           check the boot chain and GPU guards are unchanged
set -uo pipefail

# Known-good state (handoff, 2026-10-24). Update deliberately if the owner changes one.
BOOT_BIN=d6c2421e62018f7cab1d05deb7fc5170a89762ebda7444645a72eed8649cf1d2
DRIRC=76452264cbd7b7284388d1d216680404cdd5f69551b4c76b505b98e3ada0befb
PACMAN_CONF=17510c10df17a28371aec25d3e030d9e1b5d4f6e22aeaaa9bcc8323a02cae864
UPDATE_M1N1=36287d3e5e6b62b4a0b9b1ecf9ab5ee70237cf993bc54b4b38ba42b57ce310db
GRUB_ID=omarchy-j514s-sleep-chg

STOP_RE='^(linux|linux-.*|.*-headers|dkms|.*-dkms|m1n1.*|uboot-asahi|asahi-.*|grub|mkinitcpio.*|mesa.*|vulkan-.*|libdrm|libglvnd|lib32-.*|omarchy.*|hyprland|aquamarine|quickshell|qt6-base|sddm|uwsm|systemd.*|pipewire.*|wireplumber|cryptsetup|btrfs-progs|snapper|clang22|llvm22.*|rust-bindgen|libclc|spirv-llvm-translator|rustup)$'
CAUTION_RE='(firmware|^lvm2$|^mdadm$)'

sum() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
check() {  # name actual expected
    if [ "$2" = "$3" ]; then echo "ok       $1"; else echo "CHANGED  $1: ${2:-unreadable} (expected ${3:0:12}…)"; bad=1; fi
}

echo "host $(hostname) | $(uname -m) | kernel $(uname -r) | page $(getconf PAGESIZE)"

case "${1:-}" in
pre)
    shift
    [ $# -gt 0 ] || { echo "usage: $0 pre <pkg>..." >&2; exit 2; }
    # capture first: grep -q on a live pipe can SIGPIPE pacman under pipefail
    if ! tx=$(pacman -Sp --needed --print-format '%n %v %r %a' "$@" 2>&1); then
        echo "$tx"
        echo "=> not a repo install as given (AUR? typo?). Try: yay -Si NAME, or a user-level route."
        exit 1
    fi
    [ -n "$tx" ] || { echo "=> nothing to do: already installed"; exit 0; }
    echo "== transaction ($(echo "$tx" | wc -l) packages)"
    flags=0
    while read -r n v r a; do
        tag=""
        if inst=$(pacman -Q "$n" 2>/dev/null); then
            tag="UPGRADE from ${inst#* } (partial upgrade: run omarchy update first)"; flags=1
        fi
        if [[ $n =~ $STOP_RE ]]; then tag="STOP (kernel/boot/GPU/desktop core/toolchain) $tag"; flags=1
        elif [[ $n =~ $CAUTION_RE ]]; then tag="CAUTION (rebuilds all initramfs) $tag"; fi
        printf '  %-32s %-22s %-15s %-8s %s\n' "$n" "$v" "$r" "$a" "$tag"
    done <<<"$tx"
    pending=$(pacman -Qu 2>/dev/null)
    echo "== pending system updates (not installed by this): $(printf '%s' "$pending" | grep -c .)"
    [ -z "$pending" ] || echo "$pending" | sed 's/^/  /'
    [ $flags = 0 ] && echo "=> clean: owner may run: sudo pacman -S --needed $*" \
                   || echo "=> flagged lines above: explain them to the owner before any install"
    ;;
post)
    bad=0
    check "boot.bin"                  "$(sum /boot/m1n1/boot.bin)"      "$BOOT_BIN"
    check "/etc/default/update-m1n1"  "$(sum /etc/default/update-m1n1)" "$UPDATE_M1N1"
    check "/etc/drirc (GL guard)"     "$(sum /etc/drirc)"               "$DRIRC"
    check "/etc/pacman.conf"          "$(sum /etc/pacman.conf)"         "$PACMAN_CONF"
    check "GRUB default"              "$(sed -n 's/^GRUB_DEFAULT=//p' /etc/default/grub)" "$GRUB_ID"
    check "no asahi_icd.json (VK guard)" "$(ls /usr/share/vulkan/icd.d/asahi_icd.json 2>/dev/null)" ""
    check "linux-asahi m1n1 still held" "$(pacman -Q linux-asahi m1n1 2>/dev/null | tr '\n' ' ')" "linux-asahi 7.2.12.asahi1-1 m1n1 1.9.9-1 "
    failed=$(systemctl --failed --no-legend --plain 2>/dev/null; systemctl --user --failed --no-legend --plain 2>/dev/null)
    check "failed units" "$failed" ""
    echo "== /var/log/pacman.log (last transaction)"
    log=$(tail -n 400 /var/log/pacman.log)
    start=$(echo "$log" | grep -n 'transaction started' | tail -1 | cut -d: -f1)
    echo "$log" | tail -n +"${start:-1}" | grep -E '\] (installed|upgraded|removed|downgraded)|warning|error|transaction' | sed 's/^/  /'
    [ $bad = 0 ] && echo "=> all unchanged" || echo "=> CHANGED lines above: stop and tell the owner"
    exit $bad
    ;;
*)
    echo "usage: $0 pre <pkg>... | post" >&2; exit 2 ;;
esac
