该脚本为自动化备份Linux脚本，`-h`可以查看帮助，用法很简单：

```sh
chmod +x backup-linux.sh
./backup.sh DESTINATION_PATH
```

由于该流程基于btrfs文件系统，因此**下列初始化是有必要的**！

手动初始化：

```sh
# 格式分区为btrfs文件系统
sudo mkfs.btrfs /dev/partition
# 自定义自动挂载的目录名，更改btrfs文件的label
sudo btrfs filesystem label /path/to/mounted/btrfs_volume new_label
# 创建备份的路径
sudo btrfs subvolume create /path/to/backup/partition/backup
```

此外其他命令：

```sh
# 备份系统
sudo rsync -av	xHAX --numeric-ids --delete --checksum / /path/to/backup/partition/backup

# 删除snapshot
sudo btrfs subvolume delete /path/to/snapshot

# 恢复系统
sudo rsync -avxHAX --numeric-ids --delete --checksum /path/to/backup/partition/backup  /path/to/backup/partition/restore
```