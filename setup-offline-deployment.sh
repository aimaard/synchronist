#!/usr/bin/env bash
# Same as setup-deployment.sh, but without internet access: Uses the files next to this script
# and loads the docker images (*.tar) in the current directory.
exec "$(dirname "$0")/setup-deployment.sh" --offline "$@"
