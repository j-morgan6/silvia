#! /bin/sh

set -e

export MIX_ENV=prod
export MIX_TARGET=rpi0
export NERVES_HUB_ORG=Tango
export NERVES_FW_AUTHOR=Tango

mix nerves_hub.firmware publish --key tangokey --product Silvia --deploy development