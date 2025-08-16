#! /bin/sh

set -e

export MIX_ENV=prod
export MIX_TARGET=rpi0
export NERVES_HUB_ORG=Tango
export NERVES_HUB_PRODUCT=Silvia
export NERVES_FW_AUTHOR=Tango

export HOST=silvia.local

MIX_TARGET=host mix do setup, assets.deploy
mix deps.get
mix firmware

nh firmware sign ./_build/${MIX_TARGET}_${MIX_ENV}/nerves/images/silvia.fw --key tangokey

nh firmware publish ./_build/${MIX_TARGET}_${MIX_ENV}/nerves/images/silvia.fw --deploy development