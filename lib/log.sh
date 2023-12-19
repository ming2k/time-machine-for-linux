# usage: log [info|warn|error] <message> 
log() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local level=""
  local message=""

  if [ $# -eq 1 ]; then
    level="\e[32mINFO\e[0m"
    message="$1"
  elif [ $# -eq 2 ]; then
    case "$1" in
      error)
        level="\e[31mERROR\e[0m"  # 红色表示
        message="$2"
        ;;
      warn)
        level="\e[33mWARN\e[0m"  # 黄色表示
        message="$2"
        ;;
      info)
        level="\e[32mINFO\e[0m"  # 绿色表示
        message="$2"
        ;;
      *)
        echo "Invalid log level: $1"
        return
        ;;
    esac
  else
    echo "Invalid number of arguments"
    return
  fi

  echo -e "[$timestamp] [$level] $message"
}