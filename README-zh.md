# Time Machine for Linux

用 rsync 把 Linux 工作站的 `/`、`/home`、`/data` 镜像到一块加密的 BTRFS 外部盘，并在每次同步后创建只读快照。冷数据写入 `@archive` 时不使用 `--delete`。

## 备份内容

| 源 | 目标 | 行为 |
|---|---|---|
| `/` | `/mnt/@system` | rsync 镜像；删除目标端已不存在或已被排除的文件；排除 `/home`、`/data`、虚拟文件系统和可重建缓存 |
| `/home` | `/mnt/@home` | rsync 镜像；符号链接保持为链接；默认排除大媒体目录 |
| `/data` | `/mnt/@data` | rsync 镜像；排除 `archive/`、`scratch/`、`media/`、`safehouse/`、`no-backup/` 和构建产物 |
| `/data/archive/`、`~/archive/` | `/mnt/@archive` | 只追加；不传 `--delete`；可选 checksum 校验；每批创建只读快照 |
| — | `/mnt/@snapshots` | 存放 `system-backup-*`、`home-backup-*`、`data-backup-*`、`archive-batch-*` |

`@system` 是文件级镜像，不是可启动镜像。`@archive` 的“只追加”是 rsync 行为，不是 WORM。快照和镜像在同一块盘上，不防磁盘故障。

## 假定的目录结构

脚本不要求特定的发行版。要让分层恢复真正有意义，`/home` 和 `/data` 应当是独立的目录树或挂载点：

```text
/                       # 系统层：OS、/etc、/usr、/var（缓存、日志、容器、VM 镜像除外）
├── /home               # 用户层：dotfiles 和应用配置（建议独立挂载）
└── /data               # 数据层：活跃项目（建议独立挂载）
    ├── projects/       # 由 @data 备份
    ├── archive/        # 冷数据暂存；@data 排除，由 archive 命令写入 @archive
    ├── scratch/        # 不备份
    ├── media/          # 不备份
    ├── safehouse/      # 不备份
    └── no-backup/      # 不备份
```

如果 `/home` 或 `/data` 只是 `/` 下的普通目录，备份仍能运行，但它们不是独立的恢复单元；`@system` 会显式排除这两个路径。`/home` 下的符号链接保持为链接，不会跟随进入 `/data`。

备份盘默认挂载在 `/mnt`（可用 `-m` 改）：

```text
/mnt/
├── @system/            # / 的镜像
├── @home/              # /home 的镜像
├── @data/              # /data 的镜像
├── @archive/           # 冷数据；只追加
└── @snapshots/
    ├── system-backup-YYYYMMDDHHMMSS/
    ├── home-backup-YYYYMMDDHHMMSS/
    ├── data-backup-YYYYMMDDHHMMSS/
    └── archive-batch-YYYYMMDDHHMMSS/
```

`@media` 是可选的第 6 个子卷。`format-btrfs-luks.sh` 不创建它；如果手动创建，`mountctl.sh` 会一并挂载。

restore 的 `pre-restore-*` 快照写到 `--snapshots` 指定的路径；该路径通常在目标文件系统上（例如 `/home/.snapshots`），不一定位于 `/mnt/@snapshots`。

## 快速开始

依赖：Linux、`rsync`、`btrfs-progs`、`cryptsetup`，以及 root 权限。

```bash
# 1. 用 LUKS2 + BTRFS 格式化外部盘（5 个标准子卷）
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX

# 2. 解锁并挂载到 /mnt
sudo ./tools/mountctl.sh mount -d /dev/sdX

# 3. 从模板创建忽略规则
cp config/system-backup-ignore.example config/system-backup-ignore
cp config/home-backup-ignore.example config/home-backup-ignore
cp config/data-backup-ignore.example config/data-backup-ignore

# 4. 全量备份：System + Home + Data，单次确认
sudo ./bin/backup-all.sh

# 5. 归档冷数据（只追加），然后卸载
sudo ./bin/archive-sync.sh --checksum --clean-source
sudo ./tools/mountctl.sh unmount
```

单层备份：

```bash
sudo ./bin/system-backup.sh --dest /mnt/@system --snapshots /mnt/@snapshots
sudo ./bin/home-backup.sh   --dest /mnt/@home   --snapshots /mnt/@snapshots
sudo ./bin/data-backup.sh   --dest /mnt/@data   --snapshots /mnt/@snapshots
```

## 常用命令

| 任务 | 命令 |
|---|---|
| 全量备份（所有层） | `sudo ./bin/backup-all.sh` |
| 单层备份 | `sudo ./bin/<tier>-backup.sh --dest /mnt/@<tier> --snapshots /mnt/@snapshots` |
| 冷数据归档 | `sudo ./bin/archive-sync.sh [--checksum] [--clean-source]` |
| 恢复 | `sudo ./bin/<tier>-restore.sh --source ... --dest ...` |
| 挂载 / 卸载 / 状态 | `sudo ./tools/mountctl.sh mount -d <dev>` / `unmount` / `status` |
| 列出快照 | `sudo ./tools/prune-snapshots.sh --list` |
| 修剪快照 | `sudo ./tools/prune-snapshots.sh [pattern] [-k N] [--apply]` |
| BTRFS balance | `sudo ./tools/balance-btrfs.sh [path] [--quick]` |
| 清理新排除的文件 | `sudo ./tools/cleanup-excluded.sh [-t <tier>] [--execute]` |
| 格式化驱动器 | `sudo ./tools/format-btrfs-luks.sh -d <dev>` |

## 哪些内容不会被备份

- `@system`：`/home`、`/data`、`/proc`、`/sys`、`/dev`、`/run`、`/tmp`、`/mnt`、`/media`、EFI、包管理器缓存、日志、容器和 VM 镜像，以及数据库数据目录。
- `@home`：`downloads/`、`music/`、`videos/`、`books/`、`games/`、`Android/`、`sdks/`、`applications/`、`vms/` 等大目录或可重新下载的目录，以及缓存。
- `@data`：`archive/`、`scratch/`、`media/`、`safehouse/`、`no-backup/`、`node_modules/`、`target/`、`.venv/`、`dist/` 等构建产物。

完整列表见 `config/*-backup-ignore`。

## 限制

- `@system` 不是可启动镜像；bootloader 和 ESP 需要单独处理。
- `@archive` 不会删除目标端文件，但有写权限的用户仍然可以修改或删除它们。它不是 WORM。
- 快照和镜像在同一块盘上；重要数据应保留第二份异地副本。
- `--clean-source` 会在归档后删除本地文件；默认关闭，并且会要求确认。

## 文档

- [从零快速上手](docs/tutorials/getting-started.md)
- [日常备份流程](docs/how-to/routine-backup-workflow.md)
- [系统备份与恢复](docs/how-to/system-backup-and-restore.md)
- [家目录备份与恢复](docs/how-to/home-backup-and-restore.md)
- [数据区备份与恢复](docs/how-to/data-backup-and-restore.md)
- [冷数据归档](docs/how-to/archive-cold-data.md)
- [格式化加密驱动器](docs/how-to/format-btrfs-drive.md)
- [快照修剪与 BTRFS Balance](docs/how-to/maintain-btrfs-and-prune-snapshots.md)
- [CLI 参考](docs/reference/cli.md)
- [配置参考](docs/reference/configuration.md)
- [存储架构](docs/explanation/storage-architecture.md)
- [架构决策](docs/adr/index.md)

## 许可证

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE)。
