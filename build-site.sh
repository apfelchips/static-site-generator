#!/bin/sh

set -e

_SRC_DIR="$(realpath $(dirname $0))/src"

test -f "$_SRC_DIR/.env" && echo "loading settings .env from $_SRC_DIR/.env"  && . "$_SRC_DIR/.env"

_TOOLS_DIR="${TOOLS_DIR-$(realpath $(dirname $0)/tools)}"
export PATH="$_TOOLS_DIR:$PATH"


_DST_DIR="${DST_DIR-$_SRC_DIR/../dist}"
_SITE_NAME="${SITE_NAME:-Blog}"
_SITE_URL="${SITE_URL:-http://localhost:8080}"


for flag in "$@"; do
    case "$flag" in
        -h|-\?|--help)
            echo "usage: $(dirname $0)" "[--watch | --clean | --verbose]"
            ;;

        -c|--clean)
            clean=1
            ;;

        -w|--watch)
            watch=1
            shift
            ;;

        -v|--verbose)
            verbose=1
            shift
            ;;

        -s|--server)
            run_server=1
            shift
            ;;

        -?*)
            echo "WARN: Unknown option (ignored): $1" 1>&2
            shift
            ;;

        *)
            break # can't find more options, so break out of the loop.
    esac
done

if [ ! -z $verbose ] && [ $verbose -ge 1 ]; then
    set -x
fi

if [ ! -z $clean ] && [ $clean -ge 1 ]; then
    rm -rf "$_DST_DIR" || true
fi

mkdir -p "$_DST_DIR"
# rm -f "$_DST_DIR"/* && rm -f "$_DST_DIR"/.* || true # delete files on 1st level / leave folders alone --> faster build times when having large assets

"$_TOOLS_DIR/ssg.sh" "$_SRC_DIR" "$_DST_DIR" "$_SITE_NAME" "$_SITE_URL"
#"$_TOOLS_DIR/rssg.sh" "$_DST_DIR/index.html" "$_SITE_NAME" "$_SITE_URL"

if [ ! -z $watch ] && [ $watch -ge 1 ]; then
    command -v entr >/dev/null || { echo "please install entr"; exit 1; }

    while true; do
        find "$_SRC_DIR" -type f ! -path "$_SRC_DIR/.*" | entr -d "$0" -c
        sleep 0.3 # allow for user interrupts
    done
fi


if [ ! -z $run_server ] && [ $run_server -ge 1 ]; then
    php -S localhost:8080 -t "$_DST_DIR"
    echo "running server on: http://localhost:8080"
fi



