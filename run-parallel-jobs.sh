#!/bin/bash

set -eo pipefail


CLEAN="--clean"
BIG_DIR="${BIG_DIR:=|tmp:///big/|}"

while getopts ":fd:" opt; do
  case ${opt} in
    f)
      CLEAN=""
      ;;
    d)
      BIG_DIR="${OPTARG}"
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      echo "Available: "
      echo "\t-f\tDo not remove tpls"
      echo "\t-d <loc>\tOverride location where the repositories are stored and checked"
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
    java -Drascal.monitor.batch -jar target/dependencies/rascal.jar Main --repoFolder "$BIG_DIR" $CLEAN --tests $@ >"$name.log" 2>&1  &
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
