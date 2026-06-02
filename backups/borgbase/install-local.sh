#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

sudo install -d -m 0700 /etc/borgbase
sudo install -m 0700 "$SCRIPT_DIR/immich-borgbase-backup" /usr/local/sbin/immich-borgbase-backup
sudo install -m 0700 "$SCRIPT_DIR/immich-borgbase-borg" /usr/local/sbin/immich-borgbase-borg

if [[ ! -e /etc/borgbase/immich.env ]]; then
  sudo install -m 0600 "$SCRIPT_DIR/immich-borgbase.env.example" /etc/borgbase/immich.env
  echo "Created /etc/borgbase/immich.env. Edit it before running backups."
else
  echo "/etc/borgbase/immich.env already exists; leaving it unchanged."
fi

if [[ ! -e /etc/borgbase/immich-passphrase ]]; then
  echo "Create /etc/borgbase/immich-passphrase with the Borg repo passphrase, then run:"
  echo "  sudo chmod 600 /etc/borgbase/immich-passphrase"
fi
