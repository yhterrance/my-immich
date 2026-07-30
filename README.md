# Immich App


## Quick Instructions

### Update Immich

```bash
# Confirm a recent database backup exists, then run:
./upgrade-immich.sh
```

The script downloads Immich's current Compose file, keeps this host's
localhost-only binding, saves the previous Compose file in `.upgrade-backups/`,
pulls/recreates containers, and waits for health checks. It prompts for `sudo`
when Docker access requires it.

## Useful resources

- [BorgBase backup runbook](backups/borgbase/README.md)
- [Backup and Restore Immich](https://docs.immich.app/administration/backup-and-restore/)
- [Simple and Secure Offsite Borg Backups](https://www.borgbase.com/)
