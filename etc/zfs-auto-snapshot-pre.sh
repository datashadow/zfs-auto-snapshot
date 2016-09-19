#!/bin/bash

if [ "$1" = "rpool" ]; then 
    tar -czf /var/backups/pve.tar.gz /etc/pve
    chmod 600 /var/backups/pve.tar.gz
fi