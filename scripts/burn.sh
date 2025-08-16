#! /bin/sh

set -e

export MIX_ENV=dev
export MIX_TARGET=rpi0
export HOST=silvia.local

MIX_TARGET=host mix do setup, assets.deploy
mix deps.get
mix firmware
mix burn
