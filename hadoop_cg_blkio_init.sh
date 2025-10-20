#!/bin/bash

# dn nm shuffle all 根据参数来启用cgroup限制磁盘io
enable_service=$1
if [ -z "$enable_service" ]; then
  enable_service="all"
fi
echo "enable_service: $enable_service"

# 修复的磁盘检测函数 - 只返回设备号
detect_disk_devices() {
    local disks=()

    echo "开始检测磁盘设备..." >&2

    # 使用lsblk直接获取数据磁盘设备号
    while IFS= read -r line; do
        # 跳过标题行
        [[ "$line" =~ "NAME" ]] && continue

        # 提取设备名、设备号和类型
        device_name=$(echo "$line" | awk '{print $1}')
        major_minor=$(echo "$line" | awk '{print $2}')
        device_type=$(echo "$line" | awk '{print $3}')

        # 只处理磁盘设备，排除系统盘sda和分区
        if [[ "$device_type" == "disk" ]] && [[ "$device_name" =~ ^sd[b-m]$ ]]; then
            echo "发现数据磁盘: /dev/$device_name -> 设备号: $major_minor" >&2
            disks+=("$major_minor")
        fi
    done < <(lsblk -d -o NAME,MAJ:MIN,TYPE 2>/dev/null)

    # 如果没有检测到磁盘，使用预定义值
    if [ ${#disks[@]} -eq 0 ]; then
        echo "警告: 自动检测失败，使用预定义设备号" >&2
        disks=("8:16" "8:32" "8:48" "8:64" "8:80" "8:96" "8:112" "8:128" "8:144" "8:160" "8:176" "8:192")
    fi

    # 返回设备号数组
    printf '%s\n' "${disks[@]}"
}

# 使用自动检测的磁盘设备（只获取设备号）
echo "检测磁盘设备..."
DATA_DISKS=()
while IFS= read -r device; do
    DATA_DISKS+=("$device")
done < <(detect_disk_devices)

echo "检测到的数据磁盘: ${DATA_DISKS[*]}"
echo "数据磁盘数量: ${#DATA_DISKS[@]}"

# 获取服务器类型配置
server_type_name=""
if [ -f "/home/dspeak/yyms/hostinfo.ini" ]; then
    server_type_name=$(grep -E '^server_type_name\s*=' /home/dspeak/yyms/hostinfo.ini | awk -F= '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
fi
echo "server_type_name:$server_type_name"

# 设置默认限制值
limit_read_bps=62914560   # 60MB/s
limit_write_bps=52428800  # 50MB/s

# 根据服务器类型调整限制
case "$server_type_name" in
    YS13_[3456]*)
        limit_read_bps=47185920
        limit_write_bps=36700160
        echo "使用低性能配置: 读45MB/s, 写35MB/s"
        ;;
    YS13_[789]*)
        limit_read_bps=58720256
        limit_write_bps=48234496
        echo "使用中性能配置: 读56MB/s, 写46MB/s"
        ;;
    *)
        echo "使用默认配置: 读60MB/s, 写50MB/s"
        ;;
esac

setup_cgroup_io() {
    echo "开始配置磁盘IO限制..."
    echo "数据磁盘列表: ${DATA_DISKS[*]}"


    # 创建cgroup目录
    echo "创建cgroup目录..."
    mkdir -p /sys/fs/cgroup/blkio/blk_hadoop/{nodemanager,datanode,shuffle}

    # 设置权重
    echo "设置IO权重..."
    echo 300 > /sys/fs/cgroup/blkio/blk_hadoop/nodemanager/blkio.weight
    echo 400 > /sys/fs/cgroup/blkio/blk_hadoop/datanode/blkio.weight
    echo 300 > /sys/fs/cgroup/blkio/blk_hadoop/shuffle/blkio.weight


    # 为每个数据磁盘设置IO限制
    echo "设置数据磁盘IO限制..."
    for device in "${DATA_DISKS[@]}"; do
        # 验证设备号格式（主设备号:次设备号）
        if [[ ! "$device" =~ ^[0-9]+:[0-9]+$ ]]; then
            echo "跳过无效设备号: $device"
            continue
        fi
        echo "配置磁盘 $device:"
        if [[ "$enable_service" == "shuffle" || "$enable_service" == "all" ]]; then
          grep -qF "$device $limit_read_bps" /sys/fs/cgroup/blkio/blk_hadoop/shuffle/blkio.throttle.read_bps_device  ||  echo "$device $limit_read_bps" >> /sys/fs/cgroup/blkio/blk_hadoop/shuffle/blkio.throttle.read_bps_device
          grep -qF "$device $limit_write_bps" /sys/fs/cgroup/blkio/blk_hadoop/shuffle/blkio.throttle.write_bps_device || echo "$device $limit_write_bps" >> /sys/fs/cgroup/blkio/blk_hadoop/shuffle/blkio.throttle.write_bps_device
          echo "  - shuffle: 读$((limit_read_bps/1024/1024))MB/s, 写$((limit_write_bps/1024/1024))MB/s"
        fi

        if [[ "$enable_service" == "dn" || "$enable_service" == "all" ]]; then
          grep -qF "$device $limit_read_bps" /sys/fs/cgroup/blkio/blk_hadoop/datanode/blkio.throttle.read_bps_device  ||  echo "$device $limit_read_bps" >> /sys/fs/cgroup/blkio/blk_hadoop/datanode/blkio.throttle.read_bps_device
          grep -qF "$device $limit_write_bps" /sys/fs/cgroup/blkio/blk_hadoop/datanode/blkio.throttle.write_bps_device || echo "$device $limit_write_bps" >> /sys/fs/cgroup/blkio/blk_hadoop/datanode/blkio.throttle.write_bps_device
          echo "  - datanode: 读$((limit_read_bps/1024/1024))MB/s, 写$((limit_write_bps/1024/1024))MB/s"
        fi

        if [[ "$enable_service" == "nm" || "$enable_service" == "all" ]]; then
          grep -qF "$device $limit_read_bps" /sys/fs/cgroup/blkio/blk_hadoop/nodemanager/blkio.throttle.read_bps_device  ||  echo "$device $limit_read_bps" >> /sys/fs/cgroup/blkio/blk_hadoop/nodemanager/blkio.throttle.read_bps_device
          grep -qF "$device $limit_write_bps" /sys/fs/cgroup/blkio/blk_hadoop/nodemanager/blkio.throttle.write_bps_device || echo "$device $limit_write_bps" >> /sys/fs/cgroup/blkio/blk_hadoop/nodemanager/blkio.throttle.write_bps_device
          echo "  - nodemanager: 读$((limit_read_bps/1024/1024))MB/s, 写$((limit_write_bps/1024/1024))MB/s"
        fi
    done

    echo "Hadoop cgroup IO配置完成"
    echo "已配置 ${#DATA_DISKS[@]} 个数据磁盘"
    echo "启用的服务: $enable_service"
}

# 调用主函数
setup_cgroup_io
