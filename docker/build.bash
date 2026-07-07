#!/usr/bin/env bash

#
# Copyright (C) 2022 Open Source Robotics Foundation, Inc. and Monterey Bay Aquarium Research Institute
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

# Builds an Apptainer image.

# No arg
if [ $# -eq 0 ]
then
    echo "Usage: $0 directory-name"
    exit 1
fi

# Get path to current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default base image
# TODO: replace with NVIDIA-capable public image when adding NVIDIA support
base="ubuntu:noble"
image_suffix="_no_nvidia"

# Parse and remove args
PARAMS=""
while (( "$#" )); do
  case "$1" in
    --no-nvidia)
      base="ubuntu:noble"
      image_suffix="_no_nvidia"
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
# Set positional arguments in their proper place
eval set -- "$PARAMS"

if [ ! -d $DIR/$1 ]
then
  echo "image-name must be a directory in the same folder as this script"
  exit 2
fi

image_name=$(basename $1)
sif_path="$DIR/${image_name}.sif"

echo "Building $image_name with base image $base"
apptainer build --fakeroot \
  --build-arg base=$base \
  "$sif_path" \
  "$DIR/$image_name/apptainer.def"
echo "Built $sif_path"