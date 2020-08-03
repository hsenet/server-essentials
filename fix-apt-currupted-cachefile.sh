#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please use sudo to run this script"
  exit
fi

rm -rf /var/lib/apt/lists/*

apt update && apt upgrade && apt autoremove