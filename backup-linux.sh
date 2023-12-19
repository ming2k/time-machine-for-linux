#!/bin/bash

# 默认排除的文件和目录
exclude_list=(
  "/proc/*"
  "/sys/*"
  "/dev/*"
  "/tmp/*"
  "/run/*"
  "/mnt/*"
  "/media/*"
  "/lost+found"
)

# 不建议排除用户的所有cache，因为它可能保存重要内容
exclude_user_list+=(
  ".cache/httpdirfs"
)

# 函数显示帮助信息
show_help() {
  echo "Usage: $0 [OPTIONS] BACKUP_PATH"
  echo "Backup the Linux system using rsync."
  echo
  echo "Options:"
  echo "  -h, --help    Display this help and exit."
  echo
  echo "Arguments:"
  echo "  BACKUP_PATH    Specify the backup destination path."
  exit 0
}

# 函数显示错误信息并退出
show_error() {
  echo -e "\e[91mError: $1\e[0m"
  exit 1
}

# 解析命令行选项
while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help )
      show_help
      ;;
    * )
      backup_path="$1"
      shift
      ;;
  esac
done

# 检查是否提供了备份路径
if [ -z "$backup_path" ]; then
  echo "Error: Please provide a backup path."
  show_help
fi

# 构建排除选项字符串
exclude_options=""
for exclude_item in "${exclude_list[@]}"; do
  exclude_options+=" --exclude=$exclude_item"
done

# 构建用户排除选项字符串
for exclude_user_item in "${exclude_user_list[@]}"; do
  exclude_options+=" --exclude=/home/*/$exclude_user_item"
done

# 显示将要执行的排除选项，并获取用户确认
echo "\"sudo rsync -avxHAX --numeric-ids $exclude_options / "$backup_path"\" will be executed!"
read -p "Do you want to continue? (y/N) " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
  show_error "Backup operation canceled by user."
fi

current_date=$(date +"%Y%m%d")
current_time=$(date +"%H:%M:%S")
# 将时间转换为秒数
IFS=':' read -r hours minutes seconds <<< "$current_time"
seconds_since_midnight=$((hours * 3600 + minutes * 60 + seconds))

# 执行备份命令
if sudo rsync -avxHAX --numeric-ids $exclude_options / "$backup_path"; then
  echo "Backup is completed."
  # 创建快照
  sudo btrfs subvolume snapshot -r $backup_path $(dirname $backup_path)/backup-$current_date-$seconds_since_midnigh
  echo "Snapshot is created."
else
  show_error "Backup failed. Please check the error message above."
fi

