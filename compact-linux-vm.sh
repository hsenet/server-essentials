#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please use sudo to run this script"
  exit
fi

dd if=/dev/zero | pv | sudo dd of=/bigemptyfile bs=4096k

sudo rm -rf /bigemptyfile

echo "Disk space "

df -h


