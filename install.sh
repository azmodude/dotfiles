#!/bin/bash

set -e # -e: exit on error

red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)

echo "${green}Installing absolute requirements${reset}"
if [[ $(grep "^ID" /etc/os-release) =~ fedora ]]; then
  sudo dnf install -y git yubikey-manager
elif [[ $(grep "^ID" /etc/os-release) =~ opensuse ]]; then
  sudo zypper install -y git yubikey-manager
else
  echo "Unsupport distribution." && exit 1
fi

chezmoi="chezmoi"
if [ ! "$(command -v chezmoi)" ]; then
  if [[ $(grep "^ID" /etc/os-release) =~ opensuse ]]; then
    sudo zypper install -y chezmoi
  else
    bin_dir="/usr/local/bin"
    bin_dir_tmp=$(mktemp -d)
    chezmoi="$bin_dir/chezmoi"
    # chezmoi needs to be root:root owned for 1password to allow it for binary permission verification
    # which does make a lot of sense from a security perspective - therefore move it to /usr/local/bin
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$bin_dir_tmp" &&
      sudo install --owner root --group root --mode 755 --compare "${bin_dir_tmp}/chezmoi" "${chezmoi}"
  fi
fi

# stop pcscd for first use - it conflicts with gnupg when the latter is not configured to use it
sudo systemctl stop pcscd || true

# nuke .gnupg directory for clean install if yubikey is present
# secret key is on there, publics we'll just fetch
if ykman list | grep -qi yubikey; then
  rm -rf "${HOME}/.gnupg"
  pkill gpg-agent || true
fi

# import and trust our GPG Key
GPGKEY=DEE550054AA972F6
GPGKEY_FINGERPRINT=0A47650A15E4F0F4003EC450DEE550054AA972F6

# write initial .chezmoi.toml so encryption works
[[ ! -d $HOME/.config/chezmoi ]] && mkdir -p "$HOME"/.config/chezmoi
# .chezmoi.toml in here is our source of truth, delete anything already present
[[ -e $HOME/.config/chezmoi/chezmoi.toml ]] && rm -f "$HOME"/.config/chezmoi/chezmoi.toml
cat <<EOF >>"$HOME/.config/chezmoi/chezmoi.toml"
encryption = "gpg"

[gpg]
recipient = "0x${GPGKEY}"
suffix = ".asc"
EOF

gpg --keyserver keyserver.ubuntu.com --receive-keys "$GPGKEY"
echo -e "5\ny\n" | gpg --command-fd 0 --expert --edit-key "$GPGKEY_FINGERPRINT" trust
# power up yubikey if present
! ykman info 2>&1 | grep -q -i error && gpg --card-status

GPG_TTY=$(tty)
export GPG_TTY

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
# exec: replace current process with chezmoi init
# TODO: OP_SESSION_my is probably no longer supported.
#XDG_CONFIG_HOME=$HOME/.config OP_SESSION_my=$(bash bin/exact_security/executable_onepassword-signin) exec "$chezmoi" init --apply "--source=$script_dir"
# we are relying on externals to reach our target state
# therefore we need three steps to reach it - init, apply our externals and then apply the rest
XDG_CONFIG_HOME=$HOME/.config "${chezmoi}" init --source="${script_dir}"
XDG_CONFIG_HOME=$HOME/.config "${chezmoi}" apply --source="${script_dir}" "${HOME}/.externals"
XDG_CONFIG_HOME=$HOME/.config "${chezmoi}" apply --source="${script_dir}"

# vim: set ft=sh:
