current_date=$(date +"%Y%m%d")
current_time=$(date +"%H:%M:%S")
# 将时间转换为秒数
IFS=':' read -r hours minutes seconds <<< "$current_time"
seconds_since_midnight=$((hours * 3600 + minutes * 60 + seconds))

echo $seconds_since_midnight