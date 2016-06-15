#!/bin/bash
# CUPS auto disables a printer, specially a network printer if it drops out of a poor network
# this script can be used to autoenable any printers in a linux system which are disabled.
# run this script in cron, Tested on RHEL 6.4, 6.7, Ubuntu 14.04
#
# Check if a printer queue is disabled and reenable it.
 
disabled="$(lpstat -t | awk '/disabled/ { print $2 }')"
 
for printer in $disabled
do
        logger "Printer $printer is stopped"
        lprm $printer -
        /usr/sbin/cupsenable $printer && logger "Printer $printer has been enabled."
done