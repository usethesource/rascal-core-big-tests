#!/bin/bash

# override this via the `BIG_DIR` environment flag to pass in via the execution
set -exo pipefail

source parse-args.sh

TESTS=""
if [ $# -ge 0 ]; then
  TESTS="--tests $@"
fi

java -Drascal.monitor.batch -jar $RASCAL_JAR Main --repoFolder "$BIG_DIR" $CLEAN $EXTRA_ARGS $TESTS
