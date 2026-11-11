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

if [[ "$(determine_environment)" == "UNRECOGNIZED_ENVIRONMENT" ]]; then
	_log "Unrecognized environment. Exiting."
	exit 1
elif [[ "$(determine_environment)" == "WSL" ]]; then
	_log "WSL environment detected."

	_log "Uninstall service unit"
	if ! systemctl stop narada-wsl.service; then
		_log "Failed to stop narada-wsl.service. Aborting uninstall."
		exit 1
	fi
	systemctl disable narada-wsl.service
	rm -f /lib/systemd/system/narada-wsl.service
	systemctl daemon-reload

elif [[ "$(determine_environment)" == "UBUNTU_GNOME" ]]; then
	_log "Ubuntu GNOME environment detected."

	_log "Uninstall service unit"
	if ! systemctl stop narada.service; then
		_log "Failed to stop narada.service. Aborting uninstall."
		exit 1
	fi
	systemctl disable narada.service
	rm -f /lib/systemd/system/narada.service
	systemctl daemon-reload

	_log "Uninstall udev rule"
	rm -f /etc/udev/rules.d/95-narada.rules
	udevadm control --reload-rules
	udevadm trigger

fi

#####################################################################

_log "Delete installation directory"
rm -rf /opt/narada

#####################################################################
