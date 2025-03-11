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
sudo ./system-backup.sh /path/to/source /path/to/backup [/path/to/snapshots]
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

WARN:
When using rsync, you need to be careful about how you write the paths. There's an important difference between rsync -a A B and rsync -a A/ B. The first command will put directory A inside B, so you'll end up with your files in B/A. But if you add that slash after A, like rsync -a A/ B, it will copy just the contents of A into B directly. Also, when you want to exclude something, writing --exclude=C does the same thing as --exclude=C/ - both will skip the directory C and everything in it.



