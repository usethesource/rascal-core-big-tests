#!/bin/bash

set -eo pipefail

source parse-args.sh


# then we run
function runChecker() {
    local name=$1
    shift
    echo "Starting $name, trail output $name.log (tail -f $name.log in different shell to check output)"
    java -Drascal.monitor.batch -jar $RASCAL_JAR Main --update --repoFolder "$BIG_DIR" $CLEAN $EXTRA_ARGS --tests $@ >"$name.log" 2>&1  &
}

## first we have to run rascal
echo "Running rascal first, as everything depends on it"
runChecker 'rascal' 'rascal'
wait
echo "Tail out output from rascal.log"
tail 'rascal.log'

echo "Rascal is done, now lets run the rest in 2 parallel jobs"
runChecker 'libraries' 'flybytes' 'php-analysis' 'rascal-git' 'salix-core' 'drambiguity' 'salix-contrib' 'rascal-all'
runChecker 'core-and-lsp' 'typepal' 'rascal-core' 'rascal-lsp'
wait
