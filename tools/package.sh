#!/bin/sh
# Builds the three packages of the plugin in dist/, each with its checksum. All unzip to catchink.koplugin and
# differ only in the sprites they bring:
#   catchink.koplugin.zip            with the base set, normal (recommended)
#   catchink.koplugin-shiny.zip      with the base set, normal and shiny
#   catchink.koplugin-nosprites.zip  no sprites (every set is downloaded on the device)
set -eu
. "$(dirname "$0")/package_lib.sh"
package_start "catchink"
for variant in base shiny nosprites; do
    package_stage
    package_add assets/icons data
    case "$variant" in
        base) package_add sprites/base sprites/female ;;
        shiny) package_add sprites/base sprites/female sprites/shiny sprites/shiny_female ;;
    esac
    if [ "$variant" = base ]; then
        package_zip
    else
        package_zip "catchink.koplugin-$variant.zip"
    fi
done
