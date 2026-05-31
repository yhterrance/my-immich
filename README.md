# Immich App


## Quick Instructions

### Update Immich

```bash
# 1. Confirm a recent database backup exists.
ls -lh library/backups | tail

# 2. Check the target version.
grep IMMICH_VERSION .env

# 3. Edit .env if pinning a new version, for example:
# IMMICH_VERSION=v2.3.1
# Use IMMICH_VERSION=release for the latest stable release.

# 4. Pull images and restart.
docker compose pull
docker compose up -d

# 5. Confirm everything is healthy.
docker compose ps
```

After the update, open Immich and confirm the web app loads. If all looks good, optionally remove old unused images:

```bash
docker image prune
```

## Useful resources

- [Backup and Restore Immich](https://docs.immich.app/administration/backup-and-restore/)
- [Simple and Secure Offsite Borg Backups](https://www.borgbase.com/)
