#!/bin/sh
printf '\033c\033]0;%s\a' SocKapital
base_path="$(dirname "$(realpath "$0")")"
"$base_path/linux_server.x86_64" "$@"
