
CLEAN="--clean"
BIG_DIR="${BIG_DIR:=|tmp:///repo/|}"
EXTRA_ARGS=""
RASCAL_JAR=""

function printHelp() {
  echo -e "Available: "
  echo -e "\t-f\t\tDo not remove existing tpls"
  echo -e "\t-d <loc>\tOverride location where the repositories are stored and checked"
  echo -e "\t-r <path>\tOverride path of which rascal to use (should be a jar) (not a rascal loc, but an absolute regular path)"
  echo -e "\t-c <loc>\tOverride location of which rascal-core to use"
  echo -e "\t-t <loc>\tOverride location of which typepal to use"
  echo -e "\t-h\t\tThis help"
}

while getopts ":hfd:r:c:t:" opt; do
  case ${opt} in
    f)
      CLEAN=""
      ;;
    d)
      BIG_DIR="${OPTARG}"
      ;;
    r)
      EXTRA_ARGS+="--rascalVersion |file:///${OPTARG}| "
      RASCAL_JAR="${OPTARG}"
      ;;
    c)
      EXTRA_ARGS+="--rascalCoreVersion ${OPTARG} "
      ;;
    t)
      EXTRA_ARGS+="--typepalVersion ${OPTARG} "
      ;;
    h)
      printHelp
      exit 0
      ;;
    *)
      echo -e "Invalid option: -${OPTARG} ."
      printHelp
      exit 1
      ;;
  esac
done
shift $(expr $OPTIND - 1 )

if [ "$RASCAL_JAR" -eq "" ]; then
  echo "Missing rascal.jar, please provide rascal jar via -r"
  exit 1
fi
