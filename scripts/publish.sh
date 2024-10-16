#! /bin/sh

set -e

export MIX_ENV=prod
export MIX_TARGET=rpi0

mix nerves_hub.firmware publish --key tangokey --product Silvia