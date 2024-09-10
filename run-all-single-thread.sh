#!/bin/bash

# override this via the `BIG_DIR` environment flag to pass in via the execution
BIG_DIR ?= '|tmp:///big/|'

# make sure rascal.jar is present
mvn validate

# first we have to run rascal
java -jar target/dependencies/rascal.jar Main --repoFolder "$BIG_DIR" --clean 