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