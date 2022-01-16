#!/usr/bin/env bash

set -x

OLD_DISPLAY=$DISPLAY

TYPE=${1:-$XDG_SESSION_TYPE}; shift
ROOT=$1; shift
UUID=$1; shift

GNOME_SHELL_MODE_UUID=gnome-shell-mode@hedning:matrix.org
GNOME_SHELL_MODE_PARENT_DIR=${HOME}/.local/share/gnome-shell/extensions

d=0
while [ -e /tmp/.X11-unix/X${d} ]; do
    d=$((d + 1))
done
NEW_DISPLAY=:$d

XDG_RUNTIME_DIR=$(mktemp -d)

CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/${UUID}${SUFFIX}
mkdir -p $CACHE
export XDG_CONFIG_HOME=${CACHE}/config
export XDG_DATA_HOME=${CACHE}/local
mkdir -p $XDG_DATA_HOME/gnome-shell/extensions
ln -fsn $ROOT $XDG_DATA_HOME/gnome-shell/extensions/${UUID}
ln -fsn ${GNOME_SHELL_MODE_PARENT_DIR}/${GNOME_SHELL_MODE_UUID} $XDG_DATA_HOME/gnome-shell/extensions/${GNOME_SHELL_MODE_UUID}
export XDG_CACHE_HOME=${CACHE}/cache

DISPLAY=$NEW_DISPLAY
eval $(dbus-launch --exit-with-session --sh-syntax)
echo $DBUS_SESSION_BUS_ADDRESS

# #tabbed -s -n Xephyr > /dev/shm/xephyr.xid &
XEMBED=$(cat /dev/shm/xephyr.xid)

if [ -n $"XEMBED" ]; then
    XEMBED_ARGS="-parent $XEMBED"
fi


DISPLAY=$OLD_DISPLAY
args=()
case "$TYPE" in
    wayland)
        args=(--nested --wayland)
        ;;
    x11)
	if [ -n "${XEMBED}" ] && xwininfo -id "${XEMBED}" | grep Xephyr ; then
	    :
	else
	    Xephyr $NEW_DISPLAY $XEMBED_ARGS &
#	    echo "---> " Xephyr $NEW_DISPLAY $XEMBED_ARGS -screen 1024x768
#	    Xephyr $NEW_DISPLAY $XEMBED_ARGS -screen 1024x768 &
	    sleep 4
	fi
        DISPLAY=$NEW_DISPLAY
        args=--x11
        ;;
esac

# dconf reset -f /  # Reset settings
dconf write /org/gnome/shell/enabled-extensions "['${UUID}', '${GNOME_SHELL_MODE_UUID}']"
#gsettings set org.gnome.shell disable-extension-version-validation true
dconf write /org/gnome/shell/disable-extension-version-validation true

# export CLUTTER_SHOW_FPS=1
export SHELL_DEBUG=all
export MUTTER_DEBUG=1
export MUTTER_DEBUG_NUM_DUMMY_MONITORS=1
export MUTTER_DEBUG_DUMMY_MONITOR_SCALES=1
export MUTTER_DEBUG_TILED_DUMMY_MONITORS=1
gnome-shell ${args[*]} 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
