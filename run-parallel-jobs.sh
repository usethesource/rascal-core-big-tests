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

echo "To be started in parallel jobs:"
echo " 1. *-all: \`rascal-all\`, followed by \`rascal-lsp-all\` (note: fails on Windows, because \`java -jar ...\` command too long)"
echo " 2. rascal: \`rascal\` (as all libraries depend on it), followed by the libraries in two parallel jobs"

# (1)
runChecker '*-all' 'rascal-all' 'rascal-lsp-all' # Fails on Windows

# (2)
runChecker 'rascal' 'rascal'
wait $!
echo "Tail out output from rascal.log"
echo "\`\`\`"
tail 'rascal.log'
echo "\`\`\`"

echo "Rascal is done, now lets run the rest in 2 parallel jobs"
runChecker 'libraries' 'flybytes' 'salix-core' 'salix-contrib' 'drambiguity' 'rascal-git' 'php-analysis' 'typepal' 'clair' 'java-air' 'python-air' 'rascal-lucene'
runChecker 'typepal-and-lsp' 'typepal' 'rascal-lsp' # `rascal-lsp` requires TPLs to be available in the jar located by $RASCAL_JAR
wait
