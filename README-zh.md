# Time Machine for Linux

把 Linux 工作站的系统、家目录和数据区分别备份到一块加密的外部 BTRFS 硬盘上，每次备份后自动生成只读快照，可以随时回到任意一次备份时的状态。不再常用的冷数据可以单独归档，本地删掉后备份盘上依然保留。

## 快速开始

### 1. 准备环境

需要 Linux、root 权限，以及 `git`、`rsync`、`btrfs-progs`、`cryptsetup`：

```bash
# Debian / Ubuntu
sudo apt install git rsync btrfs-progs cryptsetup
# Arch Linux
sudo pacman -S git rsync btrfs-progs cryptsetup
# Fedora
sudo dnf install git rsync btrfs-progs cryptsetup
```

### 2. 获取代码

```bash
git clone https://github.com/ming2k/time-machine-for-linux.git
cd time-machine-for-linux
```

无需编译或安装，后续命令都在这个目录下执行。

### 3. 格式化备份盘（仅首次）

> [!CAUTION]
> 这一步会**清空整块硬盘**。请先用 `lsblk` 确认设备名，千万不要选错成系统盘。

```bash
lsblk                                            # 找到外部盘，例如 /dev/sdb
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX    # 设置加密密码，并创建备份所需的子卷
```

### 4. 创建忽略规则（仅首次）

```bash
cp config/system-backup-ignore.example config/system-backup-ignore
cp config/home-backup-ignore.example   config/home-backup-ignore
cp config/data-backup-ignore.example   config/data-backup-ignore
```

模板已包含合理的默认值（缓存、构建产物、大媒体目录等），可按需修改。

### 5. 执行备份

每次备份都是同样的三步：挂载 → 备份 → 卸载。

```bash
# 解锁并挂载备份盘到 /mnt
sudo ./tools/mountctl.sh mount -d /dev/sdX

# 依次备份三个层级；每条命令执行前都会请求确认
sudo ./bin/system-backup.sh --dest /mnt/@system --snapshots /mnt/@snapshots
sudo ./bin/home-backup.sh   --dest /mnt/@home   --snapshots /mnt/@snapshots
sudo ./bin/data-backup.sh   --dest /mnt/@data   --snapshots /mnt/@snapshots

# （可选）归档冷数据
sudo ./bin/archive-sync.sh --checksum

# 卸载，之后即可拔盘
sudo ./tools/mountctl.sh unmount
```

只想备份其中一层时，只运行对应的那一条命令即可。更完整的分步教程见 [从零快速上手](docs/tutorials/getting-started.md)。

## 备份内容

| 本机路径 | 备份到 | 说明 |
|---|---|---|
| `/` | `/mnt/@system` | 操作系统与配置（`/etc`、`/usr`、`/var` 等）；不含 `/home`、`/data`、缓存和日志 |
| `/home` | `/mnt/@home` | dotfiles 与应用配置；默认跳过下载、音乐、视频等大目录 |
| `/data` | `/mnt/@data` | 活跃项目；跳过 `archive/`、`scratch/` 等目录和构建产物 |
| `/data/archive/`、`~/archive/` | `/mnt/@archive` | 冷数据归档：**只增不删**，本地删除的文件不会从备份盘上消失 |
| — | `/mnt/@snapshots` | 每次备份/归档自动生成的只读快照 |

前三层是**镜像**：备份盘与本机保持一致，本机删除的文件下次备份时也会从镜像中删除，但仍可从之前的快照中找回。

## 目录结构约定

脚本不依赖特定发行版。`/home` 和 `/data` 最好是独立的分区或挂载点，这样才能分别恢复：

```text
/                       # 系统层
├── /home               # 用户层（建议独立挂载）
└── /data               # 数据层（建议独立挂载）
    ├── projects/       # 会被备份
    ├── archive/        # 冷数据暂存区，通过归档命令写入 @archive
    ├── scratch/        # 不备份
    ├── media/          # 不备份
    ├── safehouse/      # 不备份
    └── no-backup/      # 不备份
```

如果 `/home` 或 `/data` 只是 `/` 下的普通目录，备份照样能运行，只是无法作为独立单元恢复。`/home` 下的符号链接按链接本身备份，不会跟随进入 `/data`。

备份盘默认挂载在 `/mnt`（可用 `-m` 修改）：

```text
/mnt/
├── @system/            # / 的镜像
├── @home/              # /home 的镜像
├── @data/              # /data 的镜像
├── @archive/           # 冷数据归档
└── @snapshots/
    ├── system-backup-YYYYMMDDHHMMSS/
    ├── home-backup-YYYYMMDDHHMMSS/
    ├── data-backup-YYYYMMDDHHMMSS/
    └── archive-batch-YYYYMMDDHHMMSS/
```

如需存放媒体文件，可手动创建可选的 `@media` 子卷，`mountctl.sh` 会一并挂载。

## 常用命令

| 任务 | 命令 |
|---|---|
| 挂载 / 卸载 / 查看状态 | `sudo ./tools/mountctl.sh mount -d <dev>` / `unmount` / `status` |
| 单层备份 | `sudo ./bin/<tier>-backup.sh --dest /mnt/@<tier> --snapshots /mnt/@snapshots` |
| 冷数据归档 | `sudo ./bin/archive-sync.sh [--checksum] [--clean-source]` |
| 恢复 | `sudo ./bin/<tier>-restore.sh --source ... --dest ...` |
| 列出快照 | `sudo ./tools/prune-snapshots.sh --list` |
| 清理旧快照 | `sudo ./tools/prune-snapshots.sh [pattern] [-k N] [--apply]` |
| BTRFS balance | `sudo ./tools/balance-btrfs.sh [path] [--quick]` |
| 清理新排除的文件 | `sudo ./tools/cleanup-excluded.sh [-t <tier>] [--execute]` |
| 格式化备份盘 | `sudo ./tools/format-btrfs-luks.sh -d <dev>` |

`<tier>` 为 `system`、`home` 或 `data`。恢复前会自动在 `--snapshots` 指定的位置创建 `pre-restore-*` 快照，详见各恢复文档。

## 哪些内容不会被备份

- `@system`：`/home`、`/data`、`/proc`、`/sys`、`/dev`、`/run`、`/tmp`、`/mnt`、`/media`、EFI、包管理器缓存、日志、容器和 VM 镜像，以及数据库数据目录。
- `@home`：`downloads/`、`music/`、`videos/`、`books/`、`games/`、`Android/`、`sdks/`、`applications/`、`vms/` 等大目录或可重新下载的目录，以及缓存。
- `@data`：`archive/`、`scratch/`、`media/`、`safehouse/`、`no-backup/`、`node_modules/`、`target/`、`.venv/`、`dist/` 等构建产物。

完整列表见 `config/*-backup-ignore`。

## 注意事项

- `@system` 是文件级备份，不是可启动镜像；bootloader 和 EFI 分区需要单独处理。
- `@archive` 只增不删，但并非不可篡改：有写权限的用户仍可修改或删除其中的文件。
- 快照和备份在同一块盘上，盘坏了都会丢；重要数据请另外保留一份异地副本。
- `archive-sync.sh --clean-source` 会在归档成功后删除本地原文件；默认关闭，执行前会要求确认。

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
