#!/usr/bin/env bash

DEVICE=/dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0

###############################################################################
# Setup serial port
###############################################################################
stty -F $DEVICE raw ispeed 9600 ospeed 9600 cs8 -ignpar -cstopb -echo -hupcl

###############################################################################
# Set state to OFF on exit
###############################################################################
trap "echo Bye && [ -f $DEVICE ] && echo OFF > $DEVICE" EXIT

###############################################################################
# Check if any of CAPTURE streams is in running state, so it means microphone
# is in use
###############################################################################
function is_microphone_in_use {
    cat /proc/asound/card?/pcm*c/sub0/status 2>/dev/null | grep -q "state: RUNNING"
    return $?
}


###############################################################################
# Main loop
###############################################################################
while true; do
    if ( is_microphone_in_use ); then
        # echo "[$(date -Is)] microphone is: IN USE"
        echo ON > $DEVICE
    else
        # echo "[$(date -Is)] microphone is: NOT USED"
        echo OFF > $DEVICE
    fi

    sleep 10
done


