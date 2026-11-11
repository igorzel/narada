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
	script_current_dir=$(dirname "$(realpath "$0")")
	if ! POWERSHELL_EXE=$(command -v powershell.exe); then
		POWERSHELL_EXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
	fi
	if [[ ! -x "$POWERSHELL_EXE" ]]; then
		_log "Windows PowerShell was not found. Add its directory to the service PATH or mount the Windows C: drive at /mnt/c."
		exit 1
	fi
	if ! "$POWERSHELL_EXE" -NoProfile -NonInteractive -Command 'exit 0'; then
		_log "Cannot execute Windows PowerShell. Check that WSL Windows interoperability is available to this service."
		exit 1
	fi

	function is_microphone_in_use {
		mic=$("$POWERSHELL_EXE" -NoProfile -ExecutionPolicy Bypass -File "$script_current_dir/is-microphone-in-use.ps1")
		if [[ "${mic//$'\r'/}" == "True" ]]; then
			return 0
		fi

		return 1
	}

	function setupDevice {
		_log "Setting up device."
		WINDOWS_DEVICE=$("$POWERSHELL_EXE" -Command '(Get-PnpDevice -PresentOnly -FriendlyName "*CH340*").FriendlyName' | grep -o 'COM[0-9]*')
		_log "Detected Windows device: $WINDOWS_DEVICE"
	}
	function _sendCommandToDevice {
		local command=${1}
		"$POWERSHELL_EXE" -Command "\$p = New-Object -TypeName System.IO.Ports.SerialPort -ArgumentList @('$WINDOWS_DEVICE', 9600); \$p.Open(); \$p.Write(\"$command\`n\"); \$p.Close()"
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
	function _sendCommandToDevice {
		local command=${1}
		echo "$command" >$LINUX_DEVICE
	}
fi

function raiseFlag {
	_sendCommandToDevice "ON"
}
function lowerFlag {
	_sendCommandToDevice "OFF"
}

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

prev_state="UNKNOWN"
while true; do
	if (is_microphone_in_use); then
		if [[ "$prev_state" != "ON" ]]; then
			_log "Microphone is in use. Raising flag."
			raiseFlag
			prev_state="ON"
		fi
	else
		if [[ "$prev_state" != "OFF" ]]; then
			_log "Microphone is not in use. Lowering flag."
			lowerFlag
			prev_state="OFF"
		fi
	fi

	sleep 10
done
