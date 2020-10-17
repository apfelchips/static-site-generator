#!/bin/sh

set -e

_TOOLS_DIR="$(realpath $(dirname $0))"
_PROJECTS_SRC="$_TOOLS_DIR/binary-tools-src"

for project in "$_PROJECTS_SRC"/*; do

    if [ -f "$project/configure" ]; then
        echo "compiling: $project"
        cd "$project"

        chmod +x configure
        ./configure

        make

        for file in ./*; do
            file $file | grep executable | grep -v script | cut -d : -f 1 | xargs -I {} mv -f {} "$_TOOLS_DIR"/ # move compiled binaries to $_TOOLS_DIR
        done
        make clean
    fi
done
