#!/usr/bin/env python3
# Yabai - Configure scripting addition - automation
# Author: Jakub Andrysek
# Website: https://kubaandrysek.cz
# License: MIT
# GitHub: https://github.com/JakubAndrysek
# https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)#configure-scripting-addition


import os
import subprocess


def get_yabai_path():
    return subprocess.check_output("which yabai", shell=True).decode().strip()


def get_username():
    # If the script is run with sudo, SUDO_USER will be set to the user who invoked sudo
    return os.environ.get('SUDO_USER', os.environ.get('USER'))


def get_sha256_hash(file_path):
    return subprocess.check_output(f"shasum -a 256 {file_path}", shell=True).decode().split()[0]


def update_sudoers(user, hash, yabai_path):
    sudoers_line = f"{user} ALL=(root) NOPASSWD: sha256:{hash} {yabai_path} --load-sa\n"
    print(f"Writing: {sudoers_line} to /private/etc/sudoers.d/yabai")
    with open("/private/etc/sudoers.d/yabai", "w") as file:
        file.write(sudoers_line)


def main():
    yabai_path = get_yabai_path()
    user = get_username()
    yabai_hash = get_sha256_hash(yabai_path)

    update_sudoers(user, yabai_hash, yabai_path)
    print("Sudoers file updated successfully.")


if __name__ == "__main__":
    main()

