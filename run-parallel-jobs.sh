#!/bin/bash

set -eo pipefail


CLEAN="--clean"
BIG_DIR="${BIG_DIR:=|tmp:///repo/|}"
EXTRA_ARGS=""

while getopts ":fd:r:c:t:" opt; do
  case ${opt} in
    f)
      CLEAN=""
      ;;
    d)
      BIG_DIR="${OPTARG}"
      ;;
    r)
      EXTRA_ARGS+="--rascalVersion ${OPTARG} "
      ;;
    c)
      EXTRA_ARGS+="--rascalCoreVersion ${OPTARG} "
      ;;
    t)
      EXTRA_ARGS+="--typepalVersion ${OPTARG} "
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      echo "Available: "
      echo "\t-f\tDo not remove tpls"
      echo "\t-d <loc>\tOverride location where the repositories are stored and checked"
      echo "\t-r <loc>\tOverride location of which rascal to use (should be a jar)"
      echo "\t-c <loc>\tOverride location of which rascal-core to use"
      echo "\t-t <loc>\tOverride location of which typepal to use"
      exit 1
      ;;
  esac
done


# make sure rascal.jar is present
echo "Making sure rascal.jar is downloaded"
mvn validate > /dev/null 2>&1

# then we run
function runChecker() {
    local name=$1
    shift
    echo "Starting $name, trail output $name.log (tail -f $name.log in different shell to check output)"
    java -Drascal.monitor.batch -jar target/dependencies/rascal.jar Main --repoFolder "$BIG_DIR" $CLEAN $EXTRA_ARGS --tests $@ >"$name.log" 2>&1  &
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
