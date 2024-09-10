#!/bin/bash

set -eo pipefail

BIG_DIR="${BIG_DIR:=|tmp:///big/|}"

# make sure rascal.jar is present
mvn validate



# then we run
function runChecker() {
    local name=$1
    shift
    echo "Staring $name, trail output $name.log (tail -f $name.log in different shell to check output)"
    java -Drascal.monitor.batch -jar target/dependencies/rascal.jar Main --repoFolder "$BIG_DIR" --clean --tests $@ >"$name.log" 2>&1  &
}

# first we have to run rascal
echo "Running rascal first, as everything depends on it"
runChecker 'rascal' 'rascal'
wait
tail 'rascal.log'

echo "Rascal is done, now let's run the rest"
runChecker 'salix-friends' 'salix-core' 'drambiguity' 'salix-contrib'
runChecker 'other-libs' 'flybytes' 'php-analysis' 'rascal-git'
runChecker 'rascal-core' 'typepal' 'rascal-core' 'rascal-lsp'
wait