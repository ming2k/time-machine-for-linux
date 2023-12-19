# Linux 时光机器



## 准备存储

该流程基于btrfs文件系统，并要求在存储介质的根目录创建 `subvolume` 名为`backup` 用于存储系统备份，目的代替存储系统备份到根目录，防止后续创建快照查找困难。

1. 格式化文件系统：

    ```sh
    sudo mkfs.btrfs /dev/partition
    ```

2. 创建备份的路径

    ```sh
    sudo btrfs subvolume create $PARTITION/backup
    ```



## 执行备份

`backup.sh` 为自动化备份Linux脚本，`-h`可以查看帮助。

使用方法：

```sh
chmod +x backup-linux.sh
./backup.sh $PARTITION/backup
```

**跟随的是存储介质下的 `subvolume` 目录，而不是根目录！**

### 可能有帮助的命令


自定义自动挂载的目录名，更改btrfs文件的label。

```sh
sudo btrfs filesystem label /path/to/mounted/btrfs_volume new_label
```

```sh
# 备份系统
sudo rsync -av	xHAX --numeric-ids --delete --checksum / /path/to/backup/partition/backup

# 删除snapshot
sudo btrfs subvolume delete /path/to/snapshot

# 恢复系统
sudo rsync -avxHAX --numeric-ids --delete --checksum /path/to/backup/partition/backup  /path/to/backup/partition/restore
```
