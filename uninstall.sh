#!/usr/bin/env bash


#####################################################################

echo "Uninstall service unit"

systemctl disable narada.service
rm -f /lib/systemd/system/narada.service
systemctl daemon-reload


#####################################################################

echo "Uninstall udev rule"

rm -f /etc/udev/rules.d/95-narada.rules
udevadm control --reload-rules
udevadm trigger

#####################################################################

echo "Uninstall service"

rm -rf /opt/narada


#####################################################################
