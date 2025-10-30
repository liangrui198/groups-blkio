#!/bin/bash

sed -i /set_pid_blkio_cg/d /etc/cron.d/yarn-cron

cat /sys/fs/cgroup/blkio/blk_hadoop/datanode/cgroup.procs > /sys/fs/cgroup/cgroup.procs
cat /sys/fs/cgroup/blkio/blk_hadoop/nodemanger/cgroup.procs > /sys/fs/cgroup/cgroup.procs
cat /sys/fs/cgroup/blkio/blk_hadoop/shuffle/cgroup.procs > /sys/fs/cgroup/cgroup.procs

rmdir /sys/fs/cgroup/blkio/blk_hadoop/datanode
rmdir /sys/fs/cgroup/blkio/blk_hadoop/nodemanger
rmdir /sys/fs/cgroup/blkio/blk_hadoop/shuffle