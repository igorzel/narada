#!/usr/bin/env bash


#####################################################################

echo "Install service"

rm -rf /opt/narada
mkdir /opt/narada
cp narada.sh /opt/narada


#####################################################################

echo "Install udev rule"

cp 95-narada.rules /etc/udev/rules.d/
udevadm control --reload-rules
udevadm trigger

#####################################################################

echo "Install service unit"

cp ./narada.service /lib/systemd/system/
systemctl daemon-reload
sudo systemctl enable narada.service


#####################################################################



