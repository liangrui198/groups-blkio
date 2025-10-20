#!/bin/bash

# null or init blk cgroup to hadoop or remove OPS-NEV
source ../conf/OPS-NEV.sh

echo "source op $op"

if [[ $op == "dep" ]]; then
  # source ./dep.sh
  # deploy hadoop blkio limit to cgroups
  grep -qF 'mkdir -p /sys/fs/cgroup/blkio/blk_hadoop/{nodemanager,datanode,shuffle}' /etc/rc.local || echo -e "# add blkio hadoop to cgroups \nmkdir -p /sys/fs/cgroup/blkio/blk_hadoop/{nodemanager,datanode,shuffle}" >> /etc/rc.local
  wget http://xx.com:9109/topology/hadoop_cg_blkio_init.sh -O /root/hadoop_cg_blkio_init.sh
  wget http://xx.com:9109/topology/set_pid_blkio_cg.sh -O  /root/set_pid_blkio_cg.sh
  bash /root/hadoop_cg_blkio_init.sh
  grep -qF '*/1 * * * *   root /bin/bash /root/set_pid_blkio_cg.sh >/data/logs/set_pid_blkio_cg.log 2>&1' /etc/cron.d/yarn-cron || echo '*/1 * * * *   root /bin/bash /root/set_pid_blkio_cg.sh >/data/logs/set_pid_blkio_cg.log 2>&1' >> /etc/cron.d/yarn-cron
fi

if [ ! -f "/opt/cadvisor-v0.49.2-linux-amd64" ]; then
  echo "cadvisor not exist start download"
  wget http://xx.com:9109/topology/cadvisor-v0.49.2-linux-amd64 -O /opt/cadvisor-v0.49.2-linux-amd64
  chmod +x /opt/cadvisor-v0.49.2-linux-amd64
fi

capids=$(pgrep cadvisor-v0.49)

if [ -z $capids ]; then
  echo "cadvisor not exits  to start "
  nohup /opt/cadvisor-v0.49.2-linux-amd64 -port=8077 \
    -housekeeping_interval=30s -max_housekeeping_interval=60s -allow_dynamic_housekeeping=true \
    -docker_only=false \
    -raw_cgroup_prefix_whitelist=/blk_hadoop >/data/logs/cadvisor.log &
fi

echo ".............................."
echo "........done..........."
echo ".............................."
