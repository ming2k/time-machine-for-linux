# Linux Time Machine

## Prerequisite

The File System of backup media require `btrfs`. 

The following structure is recommended:

```txt
/mnt
├── @root         # Root filesystem backup
├── @snapshots    # Location for storing snapshots
└── @data         # General data backup
```


## How to use it

Basic usage:

```sh
sudo ./backup.sh /path/to/source /path/to/backup [/path/to/snapshots]
# for example
# sudo ./backup.sh /mnt/@root /mnt/external/system_backup
```

**跟随的是存储介质下的 `subvolume` 目录，而不是根目录！**

---

The following command may be helpful.

Make btrfs filesystem:

```sh
sudo mkfs.btrfs /dev/partition
```

Create subvolume:

```sh
sudo btrfs subvolume create $PARTITION/backup
```

Change subvolume name(AKA. label):

```sh
sudo btrfs filesystem label /path/to/mounted/btrfs_volume new_label
```

Delete the snapshot:

```sh
sudo btrfs subvolume delete /path/to/snapshot
```

The copy command used in the script:

```sh
sudo rsync -av	xHAX --numeric-ids --delete --checksum / /path/to/backup/partition/backup
```

Restore command that you can use:

```sh
sudo rsync -avxHAX --numeric-ids --delete --checksum /path/to/backup/partition/backup  /path/to/backup/partition/restore
```
