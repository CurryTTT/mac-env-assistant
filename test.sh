#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"
bash build.sh
executable="$project_root/dist/MacEnvAssistant.app/Contents/MacOS/EnvSetup"
for suite in --installer-test --expanded-test --environment-test --readiness-test --git-config-test; do
  echo "Running $suite"
  "$executable" "$suite"
done
