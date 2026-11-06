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

###############################################################################
if [[ "$(determine_environment)" == "UNRECOGNIZED_ENVIRONMENT" ]]; then
	_log "Unrecognized environment. Exiting."
	exit 1
elif [[ $(determine_environment) == "WSL" ]]; then
	function is_microphone_in_use {
		mic=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File './is-microphone-in-use.ps1')
		if [[ "${mic//$'\r'/}" == "True" ]]; then
			return 0
		fi

		return 1
	}

	function setupDevice {
		_log "Setting up device."
		WINDOWS_DEVICE=$(powershell.exe -Command '(Get-PnpDevice -PresentOnly -FriendlyName "*CH340*").FriendlyName' | grep -o 'COM[0-9]*')
		_log "Detected Windows device: $WINDOWS_DEVICE"
	}
	function _sendCommandToDevice {
		local command=${1}
		powershell.exe -Command "\$p = New-Object -TypeName System.IO.Ports.SerialPort -ArgumentList @('$WINDOWS_DEVICE', 9600); \$p.Open(); \$p.Write(\"$command\`n\"); \$p.Close()"
	}
	function raiseFlag {
		_sendCommandToDevice "ON"
	}
	function lowerFlag {
		_sendCommandToDevice "OFF"
	}
elif [[ $(determine_environment) == "UBUNTU_GNOME" ]]; then
	LINUX_DEVICE=/dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0

	function is_microphone_in_use {
		# Check if any of CAPTURE streams is in running state, so it means microphone is in use
		cat /proc/asound/card?/pcm*c/sub0/status 2>/dev/null | grep -q "state: RUNNING"

		return $?
	}

	function setupDevice {
		# Setup serial port
		stty -F $LINUX_DEVICE raw ispeed 9600 ospeed 9600 cs8 -ignpar -cstopb -echo -hupcl
	}

	function sendCommandToDevice {
		local command=$1
		echo "$command" >$LINUX_DEVICE
	}

	function raiseFlag {
		sendCommandToDevice "ON"
	}
	function lowerFlag {
		sendCommandToDevice "OFF"
	}

fi

###############################################################################
# Setup device
###############################################################################
setupDevice

###############################################################################
# Set state to OFF on exit
###############################################################################
function onExit {
	lowerFlag
	_log "Exiting."
}

trap "onExit" EXIT

###############################################################################
# Main loop
###############################################################################
while true; do
	if (is_microphone_in_use); then
		# echo "[$(date -Is)] microphone is: IN USE"
		_log "Microphone is in use. Raising flag."
		raiseFlag
	else
		# echo "[$(date -Is)] microphone is: NOT USED"
		_log "Microphone is not in use. Lowering flag."
		lowerFlag
	fi

	sleep 10
done
