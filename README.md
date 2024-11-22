# Linux 时光机器

## Prerequisite

The File System of backup media require `btrfs`. 

The following structure is recommended:

```txt
/mnt/backup/
├── @root         # Root filesystem backup
├── @home         # Home directory backup  
├── @snapshots    # Location for storing snapshots
└── @data         # General data backup
```


## How to Use It

Basic usage:

```sh
sudo system-backup /path/to/source /path/to/backup [/path/to/snapshots]
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
