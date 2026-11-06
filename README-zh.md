# Time Machine for Linux

[English](README.md) | [简体中文](README-zh.md)

> 类似于苹果 Time Machine 的 Linux 分层备份、即时写时复制（BTRFS Copy-on-Write）快照与不可变冷归档系统，基于 BTRFS 与 rsync 构建。

Time Machine for Linux 将现代 Linux 工作站存储划分为清晰独立的层级：以亚毫秒级 BTRFS 快照完整保护操作系统状态、用户桌面配置与活跃开发工作区，同时针对长期冷数据提供严格的**仅追加（Append-Only，绝不删除）**归档语义。

---

## 核心特性

- **独立多层级存储拓扑**：将存储严格划分为独立子卷（`@system`、`@home`、`@data`、`@archive`、`@snapshots`）。无需带入过时的根系统二进制文件，即可直接将个人用户配置完整恢复至全新发行的操作系统。
- **杜绝垃圾缓存堆积**：经过严格验证的排除规则模板，在数据写入备份磁盘前自动剔除数以 GB 计的编译中间产物（`node_modules`、`target`、`.venv`、`.pytest_cache`）以及临时包管理器缓存。
- **即时 BTRFS 快照**：利用 rsync 快速将变动同步至实时镜像子卷，随后由 BTRFS 在毫秒内创建只读写时复制快照锁定历史状态。
- **仅追加冷数据归档**：将已完工项目和不常访问的巨型数据集安全迁出至外部冷存储，支持底层数据校验（Checksum），并享有**绝不删除**的物理级保护。
- **统一 CLI 控制器 (`tm`)**：单一权威命令行入口，集中调度 LUKS 解密、挂载管理、全层级流水线备份、快照生命周期修剪以及 BTRFS 碎片回收。

---

## 存储拓扑结构

```text
[本地工作站磁盘 (热 / 温数据)]
  ├── NVMe 1 (热数据)  : / (操作系统根目录) + /home (用户配置与 dotfiles)
  └── NVMe 2 (温数据)  : /data (活跃项目代码与开发工作区)
                             │
                             │ 定期同步或手动归档
                             ▼
[外部存储驱动器 (加密 BTRFS 备份与冷存储)]
  ├── @system       <── bin/system-backup.sh (镜像同步 + 安全快照)
  ├── @home         <── bin/home-backup.sh   (镜像同步 + 安全快照)
  ├── @data         <── bin/data-backup.sh   (镜像同步 + 安全快照)
  ├── @archive      <── bin/archive-sync.sh  (仅追加 + 数据完整性校验)
  └── @snapshots    <── 时间点不可变 BTRFS 回滚快照池
```

---

## 快速上手

所有日常运维操作均由统一的 CLI 权威入口 `./tm`（或 `bin/tm`）接管。

### 1. 初始化外部存储驱动器
使用 LUKS2 加密外部硬盘并自动划分 5 个标准 BTRFS 子卷：
```bash
sudo ./tm format -d /dev/sdX
```

### 2. 一键挂载所有子卷
解锁 LUKS 容器并使用 zstd 压缩挂载所有子卷：
```bash
sudo ./tm mount /dev/sdX
```

### 3. 配置忽略规则
复制开箱即用的预设忽略规则模板：
```bash
cp config/system-backup-ignore.example config/system-backup-ignore
cp config/home-backup-ignore.example config/home-backup-ignore
cp config/data-backup-ignore.example config/data-backup-ignore
```

### 4. 执行备份
**默认行为将顺序执行所有活跃层级**（System + Home + Data），并通过单次合并提示完成确认：
```bash
sudo ./tm backup
```
*(如需针对单个层级备份：`sudo ./tm backup --data`)*

### 5. 归档冷数据与安全卸载
```bash
# 安全地将已完成项目归档至冷存储 (Append-Only，校验通过后自动清理本地空间)
sudo ./tm archive /data/archive/ --checksum --clean-source

# 逆序干净卸载所有子卷并关闭/锁定 LUKS 加密容器，随后可安全拔出硬盘
sudo ./tm unmount
```

---

## CLI 常用命令

| 命令 | 别名 | 常用参数 | 说明 |
| :--- | :--- | :--- | :--- |
| `tm backup` | `b` | `[--system] [--home] [--data] [-m <base>] [-y]` | **默认运行全部活跃层级**（系统 + 家目录 + 数据区），单次确认。可通过参数精细指定层级。 |
| `tm archive` | `a` | `[source] [--checksum] [--clean-source]` | 仅追加（Append-Only）归档冷数据至 `@archive`，并自动生成不可变只读快照。 |
| `tm restore` | `r` | `<system\|home\|data> --source <src> --dest <dst>` | 从备份镜像或历史快照中恢复文件。 |
| `tm mount` | `m` | `<dev> [-m <base>]` | 解锁 LUKS 容器并使用 zstd 压缩挂载所有子卷。 |
| `tm unmount` | `um` | `[-m <base>]` | 逆序干净卸载所有子卷并自动锁定 LUKS 容器。 |
| `tm status` | `st` | `[-m <base>]` | 查看驱动器连接状态、LUKS 解密状态与各子卷空间占用。 |
| `tm snapshots` | `snaps`| `[-s <path>]` | 格式化列出所有快照、所属层级及时间戳。 |
| `tm prune` | `p` | `[pattern] [-k <N>] [--apply]` | 按保留策略或匹配模式清理过期/脏快照（**默认仅安全演练**，需 `--apply` 生效）。 |
| `tm balance` | `bal` | `[path] [--quick]` | 执行带阈值过滤的安全 BTRFS Balance，回收稀疏块与未分配空间。 |
| `tm cleanup` | `c` | `[-t <tier>] [--execute]` | 从备份目标中清理命中新忽略规则的历史残留文件。 |
| `tm format` | `f` | `-d <dev>` | 使用 LUKS2 与 5 个标准子卷格式化初始化新驱动器。 |

---

## 相关文档

完整文档采用 [Diátaxis](https://diataxis.fr/) 架构进行体系化组织：

- **[新手教程 (Tutorials)](docs/tutorials/index.md)**：带领新用户从零搭建完整环境：
  - [从零快速上手 (Getting Started)](docs/tutorials/getting-started.md) — 15 分钟端到端完整实践。
- **[操作指南 (How-To Guides)](docs/how-to/index.md)**：聚焦特定运维场景的任务指南：
  - [日常端到端备份流程](docs/how-to/routine-backup-workflow.md) — 标准日常挂载、检查、备份与安全卸载全流程。
  - [系统备份与灾难恢复](docs/how-to/system-backup-and-restore.md) — 根分区保护与 Live USB 环境灾难恢复。
  - [用户家目录迁移](docs/how-to/home-backup-and-restore.md) — 配置文件备份与全新发行版无缝平移。
  - [工作区数据恢复与回滚](docs/how-to/data-backup-and-restore.md) — 项目源码防护与单项目即时快照恢复。
  - [冷数据安全归档](docs/how-to/archive-cold-data.md) — 双暂存区设计与仅追加冷存储。
  - [加密驱动器初始化格式化](docs/how-to/format-btrfs-drive.md) — LUKS2 加密与标准子卷划分。
  - [快照修剪与 BTRFS 空间均衡](docs/how-to/maintain-btrfs-and-prune-snapshots.md) — 保留策略与安全 chunk balance。
- **[参考规范 (Reference)](docs/reference/index.md)**：精准的技术参数与配置规范：
  - [CLI 命令行参考](docs/reference/cli.md) — 子命令全量参数、退出码及底层引擎脚本映射。
  - [配置语法规范](docs/reference/configuration.md) — rsync 匹配规则与预设排除模板规范。
- **[原理剖析 (Explanation)](docs/explanation/index.md)**：深入理解架构设计理念与技术选型：
  - [存储拓扑与分层逻辑](docs/explanation/storage-architecture.md) — 子卷拆分理念与 rsync + 写时复制快照协同机制。
  - [备份原则与反囤积法则](docs/explanation/backup-principles.md) — 可恢复性与不可替代性，清单优于拷贝。
  - [预检检查机制设计](docs/explanation/preflight-checks.md) — 容量阈值、快照堆积与健康状态前置拦截。
- **[子系统架构蓝图 (Subsystem Architecture)](docs/dev/subsystems.md)**：工程拓扑、模块职责与架构不变量约束。
- **[架构决策记录 (ADR)](docs/adr/index.md)**：核心决策演进、权衡考量与否定知识记录。

---

## 许可证

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE)。
