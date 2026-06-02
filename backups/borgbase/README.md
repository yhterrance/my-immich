# BorgBase backups for Immich

This runbook sets up encrypted BorgBase backups for the Immich server in this repository.

The tracked files in this directory are safe templates. Keep the real BorgBase repo URL, private SSH key, and Borg passphrase only on the OVH server and in an external password manager.

## Files

- `immich-borgbase-backup`: backup script to install at `/usr/local/sbin/immich-borgbase-backup`
- `immich-borgbase-borg`: helper wrapper that loads `/etc/borgbase/immich.env` and runs `borg`
- `immich-borgbase.env.example`: config template to copy to `/etc/borgbase/immich.env`
- `install-local.sh`: local installer for the script and config template

## 1. Create the BorgBase repo

In BorgBase:

1. Create a repo named `immich-ovh`.
2. Pick a region that is close enough, but preferably not the same provider and region as OVH.
3. Set the quota near the current `UPLOAD_LOCATION` size plus expected growth.
4. Copy the repo URL, which looks like:

```bash
ssh://xxxx@xxxx.repo.borgbase.com/./repo
```

To estimate the current upload size on this server:

```bash
du -sh /home/terrance/immich-app/library
```

## 2. Install Borg on OVH

```bash
sudo apt update
sudo apt install borgbackup
borg --version
```

## 3. Create one SSH key for this server

Run this as root because the cron job and backup script run as root:

```bash
sudo install -d -m 0700 /root/.ssh
sudo ssh-keygen -t ed25519 -f /root/.ssh/immich_borgbase -C "immich-ovh-borgbase"
sudo cat /root/.ssh/immich_borgbase.pub
```

Add the public key in BorgBase under `Account > SSH Keys`, then assign it to the `immich-ovh` repo. The private key stays only at `/root/.ssh/immich_borgbase` on this server.

If you already created the key as `terrance` at `/home/terrance/.ssh/immich_borgbase`, move a protected copy into root's SSH directory instead of pointing root cron at the user home:

```bash
sudo install -d -m 0700 /root/.ssh
sudo install -o root -g root -m 0600 /home/terrance/.ssh/immich_borgbase /root/.ssh/immich_borgbase
sudo install -o root -g root -m 0644 /home/terrance/.ssh/immich_borgbase.pub /root/.ssh/immich_borgbase.pub
sudo cat /root/.ssh/immich_borgbase.pub
```

The copied public key should match the key assigned to the BorgBase repo. After the root backup works, remove the duplicate private key from `/home/terrance/.ssh` unless you need it for a separate user-level workflow.

## 4. Initialize the BorgBase repo with encryption

Use the real repo URL from BorgBase:

```bash
export BORG_REPO='ssh://xxxx@xxxx.repo.borgbase.com/./repo'
export BORG_RSH='ssh -i /root/.ssh/immich_borgbase -o IdentitiesOnly=yes'
borg init --encryption=repokey-blake2
```

Use a long random passphrase and store it outside OVH, for example in 1Password. Without this passphrase, restore is impossible.

## 5. Install the tracked backup script

Recommended on this server: install the scripts for root. The current Immich upload directory is readable by `terrance`, but not writable, and `terrance` does not currently have Docker socket access. The backup needs Docker access for `pg_dumpall` and write access to create the database dump before Borg runs.

From this repository:

```bash
cd /home/terrance/immich-app
chmod +x backups/borgbase/install-local.sh
sudo backups/borgbase/install-local.sh
```

Edit the root-only config:

```bash
sudo nano /etc/borgbase/immich.env
sudo chmod 600 /etc/borgbase/immich.env
```

Set at least:

```bash
BORG_REPO="ssh://xxxx@xxxx.repo.borgbase.com/./repo"
UPLOAD_LOCATION="/home/terrance/immich-app/library"
DB_USERNAME="postgres"
```

Create the root-only passphrase file:

```bash
sudo nano /etc/borgbase/immich-passphrase
sudo chmod 600 /etc/borgbase/immich-passphrase
```

The file should contain only the Borg repository passphrase.

### User-level alternative

You can install this as a user-level backup, but make the tradeoffs explicit:

- The user must be able to run `docker exec` against `immich_postgres`.
- The user must be able to write the database dump into `UPLOAD_LOCATION/database-backup`.
- Adding a user to the `docker` group is effectively root-equivalent on the host.
- User-level config and passphrase files are easier to keep in the home directory, but they are not meaningfully safer if the user also has Docker access.

Example for user `terrance`:

```bash
install -d -m 0700 ~/.local/bin ~/.config/borgbase ~/.ssh
install -m 0700 backups/borgbase/immich-borgbase-backup ~/.local/bin/immich-borgbase-backup
install -m 0700 backups/borgbase/immich-borgbase-borg ~/.local/bin/immich-borgbase-borg
install -m 0600 backups/borgbase/immich-borgbase.env.example ~/.config/borgbase/immich.env
```

Edit `~/.config/borgbase/immich.env`:

```bash
IMMICH_APP_DIR="/home/terrance/immich-app"
UPLOAD_LOCATION="/home/terrance/immich-app/library"
DB_CONTAINER="immich_postgres"
DB_USERNAME="postgres"
BORG_REPO="ssh://xxxx@xxxx.repo.borgbase.com/./repo"
BORG_KEY_FILE="/home/terrance/.ssh/immich_borgbase"
BORG_PASSPHRASE_FILE="/home/terrance/.config/borgbase/immich-passphrase"
LOCK_FILE="/tmp/immich-borgbase-backup-terrance.lock"
```

Create the user-level SSH key and add its public key to BorgBase:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/immich_borgbase -C "immich-ovh-borgbase"
cat ~/.ssh/immich_borgbase.pub
```

Create the user-level passphrase file:

```bash
nano ~/.config/borgbase/immich-passphrase
chmod 600 ~/.config/borgbase/immich.env ~/.config/borgbase/immich-passphrase
```

Grant Docker access only if you accept that this is root-equivalent:

```bash
sudo usermod -aG docker terrance
```

Log out and back in after changing groups.

Create a writable dump directory inside the Immich upload location:

```bash
sudo install -d -o terrance -g terrance -m 0700 /home/terrance/immich-app/library/database-backup
```

Run with the user config:

```bash
IMMICH_BORGBASE_CONFIG="$HOME/.config/borgbase/immich.env" ~/.local/bin/immich-borgbase-backup
IMMICH_BORGBASE_CONFIG="$HOME/.config/borgbase/immich.env" ~/.local/bin/immich-borgbase-borg list
```

User crontab example:

```cron
30 3 * * * IMMICH_BORGBASE_CONFIG="$HOME/.config/borgbase/immich.env" "$HOME/.local/bin/immich-borgbase-backup" >> "$HOME/.local/state/immich-borgbase-backup.log" 2>&1
```

## 6. Test one manual backup

```bash
sudo /usr/local/sbin/immich-borgbase-backup
```

List archives:

```bash
sudo /usr/local/sbin/immich-borgbase-borg list
```

Mount a restore test:

```bash
sudo mkdir -p /tmp/immich-restore-test
sudo /usr/local/sbin/immich-borgbase-borg mount /tmp/immich-restore-test
ls /tmp/immich-restore-test
sudo /usr/local/sbin/immich-borgbase-borg umount /tmp/immich-restore-test
```

If mounting is not available because FUSE is missing, install it:

```bash
sudo apt install fuse3
```

## 7. Schedule nightly backups

Edit root's crontab:

```bash
sudo crontab -e
```

Add:

```cron
30 3 * * * /usr/local/sbin/immich-borgbase-backup >> /var/log/immich-borgbase-backup.log 2>&1
```

## Security hardening

After the first backup and restore test work, enable append-only access for this server's BorgBase SSH key if BorgBase offers it for the repo/key.

Append-only access protects old archives if the OVH server is compromised. The tradeoff is that `borg prune` and `borg compact` will not actually free remote space while using an append-only key. Periodically run cleanup with a separate full-access key that is kept off the OVH server.

## What gets backed up

The script creates a fresh database dump at:

```text
/home/terrance/immich-app/library/database-backup/immich-database.sql
```

Then it backs up the full Immich upload location, excluding generated data:

- `/home/terrance/immich-app/library/thumbs`
- `/home/terrance/immich-app/library/encoded-video`

Those excluded directories can be regenerated by Immich. The database dump is included in the archive alongside the original assets.

## Sources

- Immich backup and restore docs: https://docs.immich.app/administration/backup-and-restore/
- Immich Borg template: `docs/docs/guides/template-backup-script.md` in the Immich docs repository
- BorgBase CLI setup: https://docs.borgbase.com/setup/borg/cli/
- Borg `init` encryption docs: https://borgbackup.readthedocs.io/en/stable/usage/init.html
