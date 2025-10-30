#!/bin/bash


# dn nm shuufle all 根据参数来启用cgroup限制磁盘io
enable_service=$1
if [ -z "$enable_service" ]; then
  enable_service="all"
fi
echo "enable_serivce: $enable_service"

get_datanode_worker_pid() {
    local worker_pid=""
    # 方法1: 通过用户字段
    ps -ef | grep datanode | grep -v grep | while read user pid ppid rest; do
        if [ "$user" = "hdfs" ]; then
            worker_pid=$pid
            echo "通过用户字段找到工作进程: $worker_pid (用户: $user, 父进程: $ppid)" >&2
            echo $worker_pid
            return
        fi
    done
    echo "$worker_pid"
}


assign_processes() {
    # 将进程分配到对应的cgroup
    # NodeManager进程
    if [[ "$enable_service" == "nm" || "$enable_service" == "all" ]]; then
      NM_PID=$(pgrep -f "nodemanager|NodeManager" | head -1)
      if [ ! -z "$NM_PID" ]; then
          echo "分配NodeManager进程: $NM_PID"
          echo $NM_PID > /sys/fs/cgroup/nodemanager/cgroup.procs
      fi
    fi
    # DataNode进程
    if [[ "$enable_service" == "dn" || "$enable_service" == "all" ]]; then
      # DN_ROOT_PID=$(pgrep -f "SecureDataNodeStarter" | head -1)
      DN_WORKER_PID=$(get_datanode_worker_pid)
      if [ ! -z "$DN_WORKER_PID" ]; then
          echo "分配DataNode工作进程: $DN_WORKER_PID"
          echo $DN_WORKER_PID > /sys/fs/cgroup/datanode/cgroup.procs
      else
          echo "警告: 未找到DataNode工作进程"
      fi
    fi

    # shuffle进程（如果在当前节点）
    if [[ "$enable_service" == "shuffle" || "$enable_service" == "all" ]]; then
      SHUFFLE_PID=$(pgrep -f Worker)
      if [ ! -z "$SHUFFLE_PID" ]; then
          echo "分配shuffle工作进程: $DN_WORKER_PID"
          echo $SHUFFLE_PID > /sys/fs/cgroup/shuffle/cgroup.procs
      else
          echo "警告: 未找到shuffle工作进程"
      fi
    fi
    echo "进程分配完成"
}

assign_processes