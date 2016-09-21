#!/bin/bash

if [ "$1" = "rpool" ]; then 
    tar -czf /var/backups/pve.tar.gz -C / etc/pve
    zfs list -oname,mountpoint >/var/backups/zfs-mp
    chmod 600 /var/backups/pve.tar.gz /var/backups/zfs-mp
fi
