#!/usr/bin/env bash

#######################################################################
# Logging utility function
#######################################################################
function _log {
	local message=$1
	echo "[$(date -Is)] $message" >&2
}

#######################################################################
# Determine if we are running in WSL or Ubuntu GNOME
#######################################################################
function determine_environment {
	if [[ -f /etc/wsl.conf ]]; then
		echo "WSL"
	elif [[ "$XDG_CURRENT_DESKTOP" == "ubuntu:GNOME" ]]; then
		echo "UBUNTU_GNOME"
	else
		echo "UNRECOGNIZED_ENVIRONMENT"
	fi
}

#####################################################################

_log "Install service"

rm -rf /opt/narada
mkdir /opt/narada

cp narada.sh /opt/narada

#####################################################################

if [[ "$(determine_environment)" == "UBUNTU_GNOME" ]]; then
	_log "Ubuntu GNOME environment detected."
	_log "Install udev rule"

	cp 95-narada.rules /etc/udev/rules.d/
	udevadm control --reload-rules
	udevadm trigger

	_log "Install service unit"

	cp ./narada.service /lib/systemd/system/
	systemctl daemon-reload
	systemctl enable narada.service
	systemctl start narada.service
elif [[ "$(determine_environment)" == "WSL" ]]; then
	_log "WSL environment detected."
	_log "Install powershell script"
	cp ./is-microphone-in-use.ps1 /opt/narada/

	_log "Install service unit"

	cp ./narada-wsl.service /lib/systemd/system/
	systemctl daemon-reload
	systemctl enable narada-wsl.service
	systemctl start narada-wsl.service
fi

#####################################################################
