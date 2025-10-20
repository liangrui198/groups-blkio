#!/bin/bash

# deploy hadoop blkio limit to cgroups
grep -qF 'mkdir -p /sys/fs/cgroup/blkio/blk_hadoop/{nodemanager,datanode,shuffle}' /etc/rc.local || echo -e "# add blkio hadoop to cgroups \nmkdir -p /sys/fs/cgroup/blkio/blk_hadoop/{nodemanager,datanode,shuffle}" >> /etc/rc.local

wget http://xx.com:9109/topology/hadoop_cg_blkio_init.sh -O /root/hadoop_cg_blkio_init.sh
wget http://xx.com:9109/topology/set_pid_blkio_cg.sh -O  /root/set_pid_blkio_cg.sh

bash /root/hadoop_cg_blkio_init.sh
grep -qF '*/1 * * * *   root /bin/bash /root/set_pid_blkio_cg.sh >/data/logs/set_pid_blkio_cg.log 2>&1' /etc/cron.d/yarn-cron || echo '*/1 * * * *   root /bin/bash /root/set_pid_blkio_cg.sh >/data/logs/set_pid_blkio_cg.log 2>&1' >> /etc/cron.d/yarn-cron
