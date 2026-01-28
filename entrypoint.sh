#!/bin/bash

# set java home
update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java

# Start docker
start-docker.sh

# Start sshd
echo "root:$ROOT_PWD"| chpasswd
service ssh start

# Start VNC server
rm -rf /tmp/.X0-lock && rm -rf /tmp/.X11-unix/X0
echo ${VNCPWD} | vncpasswd -f > /root/.vnc/passwd
vncserver :0 -rfbport ${VNCPORT} -geometry $VNCDISPLAY -depth $VNCDEPTH
"$@"