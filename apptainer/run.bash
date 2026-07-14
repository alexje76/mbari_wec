##Likely do not use on HYAK at all

#!/usr/bin/env bash

#
# Copyright (C) 2023 Open Source Robotics Foundation, Inc. and Monterey Bay Aquarium Research Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#

# Runs an Apptainer instance with the image created by build.bash
# Requires:
#   apptainer
#   an X server
# Optional:
#   NVIDIA support (future)
#   A joystick mounted to /dev/input/js0 or /dev/input/js1

if [ $# -lt 1 ]
then
    echo "Usage: $0 <apptainer image (.sif)> [<dir with workspace> ...]"
    exit 1
fi

# Default to no NVIDIA (only --no-nvidia supported for now; NVIDIA opts left for future use)
# TODO: when adding NVIDIA support, populate APPTAINER_OPTS here
#APPTAINER_OPTS="--nv"  # basic NVIDIA passthrough
APPTAINER_OPTS=""

# workarounds for MESA/ZINK Vulkan issue
# TODO: revisit these bind mounts when adding NVIDIA support
#APPTAINER_OPTS="$APPTAINER_OPTS --bind /usr/share/glvnd/egl_vendor.d/10_nvidia.json:/usr/share/glvnd/egl_vendor.d/10_nvidia.json"

# Parse and remove args
PARAMS=""
while (( "$#" )); do
  case "$1" in
    --no-nvidia)
        APPTAINER_OPTS=""
      shift
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done
# set positional arguments in their proper place
eval set -- "$PARAMS"

IMG=$1

ARGS=("$@")
WORKSPACES=("${ARGS[@]:1}")

# Make sure processes in the container can connect to the x server
# Necessary so gazebo can create a context for OpenGL rendering (even headless)
XAUTH=/tmp/.apptainer.xauth
if [ ! -f $XAUTH ]
then
    xauth_list=$(xauth nlist $DISPLAY | sed -e 's/^..../ffff/')
    if [ ! -z "$xauth_list" ]
    then
        touch $XAUTH
        echo $xauth_list | xauth -f $XAUTH nmerge -
    else
        touch $XAUTH
    fi
    chmod a+r $XAUTH
fi

BIND_OPTS=""

# Share your vim settings.
VIMRC=~/.vimrc
if [ -f $VIMRC ]
then
  BIND_OPTS="$BIND_OPTS --bind $VIMRC:/home/developer/.vimrc:ro"
fi

# Share your custom terminal setup commands
GITCONFIG=~/.gitconfig
BIND_OPTS="$BIND_OPTS --bind $GITCONFIG:/home/developer/.gitconfig:ro"

for WS_DIR in ${WORKSPACES[@]}
do
  WS_DIRNAME=$(basename $WS_DIR)
  if [ ! -d $WS_DIR/src ]
  then
    echo "Other! $WS_DIR"
    BIND_OPTS="$BIND_OPTS --bind $WS_DIR:/home/developer/other/$WS_DIRNAME"
  else
    echo "Workspace! $WS_DIR"
    BIND_OPTS="$BIND_OPTS --bind $WS_DIR/src:/home/developer/workspaces/src"
  fi
done

mkdir -p $PWD/logs  # for pbloghome

# Derive a stable instance name from the image filename
INSTANCE_NAME=$(basename "$IMG" .sif)

# Stop any pre-existing instance with the same name
apptainer instance stop "$INSTANCE_NAME" 2>/dev/null || true

apptainer instance start \
  --writable-tmpfs \
  --net \
  --network none \
  --env RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
  --env GZ_VERSION=harmonic \
  --bind "/etc/localtime:/etc/localtime:ro" \
  --bind "/dev:/dev" \
  --bind "$PWD/logs:/logs" \
  $BIND_OPTS \
  $APPTAINER_OPTS \
  "$IMG" \
  "$INSTANCE_NAME"

echo "Instance '$INSTANCE_NAME' started. Use join.bash $IMG to attach."