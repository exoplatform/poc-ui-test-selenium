#!/bin/bash -eu

#Activate aliases usage in scripts
shopt -s expand_aliases

# Various command aliases
#alias display_time='/usr/bin/time -f "[INFO] Return code : %x\n[INFO] Time report (sec) : \t%e real,\t%U user,\t%S system"'
alias display_time='/usr/bin/time'

# ####################################
# Generic bash functions library
# ####################################

# OS specific support. $var _must_ be set to either true or false.
CYGWIN=false
LINUX=false;
OS400=false
DARWIN=false
case "`uname`" in
  CYGWIN*) CYGWIN=true ;;
  Linux*) LINUX=true ;;
  OS400*) OS400=true ;;
  Darwin*) DARWIN=true ;;
esac

# Rsync directory $1 -> $2
# Parameters :
# * $1 : origin path
# * $2 : destination path
function rsync_directories {
  mkdir -p $1
  display_time rsync --delete-during --inplace --stats -haAXPW $1 $2
}

do_curl() {
  if [ $# -lt 4 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function do_curl !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local _curlOptions="$1";
  shift;
  local _url="$1";
  shift;
  local _filePath="$1";
  shift;
  local _description="$1";
  shift;

  echo "[INFO] Downloading $_description from $_url ..."
  set +e
  curl $_curlOptions "$_url" > $_filePath
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, cannot download $_description"
    rm -f $_filePath # Remove potential corrupted file
    exit 1
  fi
  set -e
  echo "[INFO] $_description downloaded"
  echo "[INFO] Local path : $_filePath"
}

#
# Function that downloads an artifact from nexus
# It will be updated if a SNAPSHOT is asked and a more recent version exists
# Because Nexus REST APIs don't use Maven 3 metadata to download the latest SNAPSHOT
# of a given GAVCE we need to manually get the timestamp using xpath
# see https://issues.sonatype.org/browse/NEXUS-4423
#
do_download_from_nexus() {
  if [ $# -lt 10 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function do_download_from_nexus !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local _repositoryURL="$1";
  shift;
  local _repositoryUsername="$1";
  shift;
  local _repositoryPassword="$1";
  shift;
  local _artifactGroupId="$1";
  shift;
  local _artifactArtifactId="$1";
  shift;
  local _artifactVersion="$1";
  shift;
  local _artifactPackaging="$1";
  shift;
  local _artifactClassifier="$1";
  shift;
  local _downloadDirectory="$1";
  shift;
  local _fileBaseName="$1";
  shift;
  local _prefix="$1";
  shift; # Used to _prefix variables that store artifact details

  #
  # Local variables
  #
  local _artifactDate="" # We can compute the artifact date only for SNAPSHOTs
  local _artifactTimestamp="$_artifactVersion" # By default we set the timestamp to the given version (for a release)
  local _isTimestamp=false
  local _isRelease=false
  local _isSnapshot=false
  if [[ "$_artifactVersion" =~ .*-SNAPSHOT ]]; then
    # If this is a SNAPSHOT
    _isSnapshot=true
  elif [[ "$_artifactVersion" =~ .*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]+ ]]; then
    # If this is a TIMESTAMP we need to set the version to -SNAPSHOT
    _artifactVersion=`expr "$_artifactTimestamp" : '\(.*\)-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]\+'`"-SNAPSHOT"
    _isTimestamp=true
  else
    _isRelease=true
  fi
  local _baseUrl="${_repositoryURL}/${_artifactGroupId//.//}/$_artifactArtifactId/$_artifactVersion" # base url where to download from
  local _curlOptions="";

  # Credentials and options
  if [ -n "$_repositoryUsername" ]; then
    _curlOptions="--fail --show-error --location-trusted -u $_repositoryUsername:$_repositoryPassword" # Repository credentials and options
  else
    _curlOptions="--fail --show-error --location-trusted"
  fi

  # Create the directory where we will download it
  mkdir -p $_downloadDirectory

  #
  # For a SNAPSHOT we will need to manually compute its TIMESTAMP from maven metadata
  #
  if $_isSnapshot; then
    local _metadataFile="$_downloadDirectory/$_fileBaseName-$_artifactVersion-maven-metadata.xml"
    local _metadataUrl="$_baseUrl/maven-metadata.xml"
    # Backup lastest metadata to be able to use them if newest are wrong
    # (were removed from nexus for example thus we can use what we have in our local cache)
    if [ -e "$_metadataFile" ]; then
      mv $_metadataFile $_metadataFile.bck
    fi
    do_curl "$_curlOptions" "$_metadataUrl" "$_metadataFile" "Artifact Metadata"
    local _xpathQuery="";
    if [ -z "$_artifactClassifier" ]; then
      _xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(not(classifier))and(extension=\"$_artifactPackaging\")]/value/text()"
    else
      _xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(classifier=\"$_artifactClassifier\")and(extension=\"$_artifactPackaging\")]/value/text()"
    fi
    set +e
    if $DARWIN; then
      _artifactTimestamp=`xpath $_metadataFile $_xpathQuery`
    fi
    if $LINUX; then
      _artifactTimestamp=`xpath -q -e $_xpathQuery $_metadataFile`
    fi
    set -e
    if [ -z "$_artifactTimestamp" ] && [ -e "$_metadataFile.bck" ]; then
      # We will restore the previous one to get its timestamp and redeploy it
      echo "[WARNING] Current metadata invalid (no more package in the repository ?). Reinstalling previous downloaded version."
      mv $_metadataFile.bck $_metadataFile
      if $DARWIN; then
        _artifactTimestamp=`xpath $_metadataFile $_xpathQuery`
      fi
      if $LINUX; then
        _artifactTimestamp=`xpath -q -e $_xpathQuery $_metadataFile`
      fi
    fi
    if [ -z "$_artifactTimestamp" ]; then
      echo "[ERROR] No package available in the remote repository and no previous version available locally."
      exit 1;
    fi
    rm -f $_metadataFile.bck
    echo "[INFO] Latest timestamp : $_artifactTimestamp"
    _artifactDate=`expr "$_artifactTimestamp" : '.*-\(.*\)-.*'`
  fi

  #
  # Compute the Download URL for the artifact
  #
  local _filename=$_artifactArtifactId-$_artifactTimestamp
  local _name=$_artifactGroupId:$_artifactArtifactId:$_artifactVersion
  if [ -n "$_artifactClassifier" ]; then
    _filename="$_filename-$_artifactClassifier"
    _name="$_name:$_artifactClassifier"
  fi
  _filename="$_filename.$_artifactPackaging"
  _name="$_name:$_artifactPackaging"
  local _artifactUrl="$_baseUrl/$_filename"
  local _artifactFile="$_downloadDirectory/$_fileBaseName-$_artifactTimestamp.$_artifactPackaging"

  #
  # Download the artifact SHA1
  #
  local _sha1Url="${_artifactUrl}.sha1"
  local _sha1File="${_artifactFile}.sha1"
  if [ ! -e "$_sha1File" ]; then
    do_curl "$_curlOptions" "$_sha1Url" "$_sha1File" "Artifact SHA1"
  fi

  #
  # Download the artifact
  #
  if [ -e "$_artifactFile" ]; then
    echo "[INFO] $_name was already downloaded. Skip artifact download !"
  else
    do_curl "$_curlOptions" "$_artifactUrl" "$_artifactFile" "Artifact $_name"
  fi

  #
  # Validate download integrity
  #
  echo "[INFO] Validating download integrity ..."
  # Read the SHA1 from Maven
  read -r mavenSha1 < $_sha1File || true
  echo "$mavenSha1  $_artifactFile" > $_sha1File.tmp
  set +e
  shasum -c $_sha1File.tmp
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $_name download integrity failed"
    rm -f $_artifactFile
    rm -f $_sha1File
    rm -f $_sha1File.tmp
    exit 1
  fi
  set -e
  rm -f $_sha1File.tmp
  echo "[INFO] Download integrity validated."

  #
  # Validate archive integrity
  #
  echo "[INFO] Validating archive integrity ..."
  set +e
  case "$_artifactPackaging" in
    zip)
      zip -T $_artifactFile
    ;;
    jar | war | ear)
      jar -tf $_artifactFile > /dev/null 2>&1
    ;;
    tar.gz | tgz)
      gzip -t $_artifactFile
    ;;
    *)
      echo "[WARNING] No method to validate \"$_artifactPackaging\" file type."
    ;;
  esac
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $_name archive integrity failed. Local copy is deleted."
    rm -f $_artifactFile
    rm -f $mavenSha1
    exit 1
  fi
  set -e
  echo "[INFO] Archive integrity validated."

  #
  # Create an info file with all details about the artifact
  #
  local _artifactInfo="$_downloadDirectory/$_fileBaseName-$_artifactTimestamp.info"
  echo "[INFO] Creating archive descriptor ..."
  cat << EOF > $_artifactInfo
${_prefix}_VERSION="$_artifactVersion"
${_prefix}_ARTIFACT_GROUPID="$_artifactGroupId"
${_prefix}_ARTIFACT_ARTIFACTID="$_artifactArtifactId"
${_prefix}_ARTIFACT_TIMESTAMP="$_artifactTimestamp"
${_prefix}_ARTIFACT_DATE="$_artifactDate"
${_prefix}_ARTIFACT_CLASSIFIER="$_artifactClassifier"
${_prefix}_ARTIFACT_PACKAGING="$_artifactPackaging"
${_prefix}_ARTIFACT_URL="$_artifactUrl"
${_prefix}_ARTIFACT_LOCAL_PATH="$_artifactFile"
EOF

  echo "[INFO] Done."
  #Display the deployment descriptor
  echo "[INFO] ========================== Archive Descriptor ==========================="
  cat $_artifactInfo
  echo "[INFO] ========================================================================="

  #
  # Create a symlink if it is a SNAPSHOT to the TIMESTAMPED version
  #
  if $_isSnapshot; then
    ln -fs "$_fileBaseName-$_artifactTimestamp.$_artifactPackaging" "$_downloadDirectory/$_fileBaseName-$_artifactVersion.$_artifactPackaging"
    ln -fs "$_fileBaseName-$_artifactTimestamp.info" "$_downloadDirectory/$_fileBaseName-$_artifactVersion.info"
  fi
}

do_load_artifact_descriptor() {
  if [ $# -lt 3 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function do_load_artifact_descriptor !"
    exit 1;
  fi
  local _downloadDirectory="$1";
  shift;
  local _fileBaseName="$1";
  shift;
  local _artifactVersion="$1";
  shift;
  source "$_downloadDirectory/$_fileBaseName-$_artifactVersion.info"
}

# Backup the file passed as parameter
backup_logs() {
  if [ -d $1 ]; then
    # We need to backup existing logs if they already exist
    cd $1
    local _start_date=`date -u "+%Y%m%d-%H%M%S-UTC"`
    for file in $2
    do
      if [ -e $file ]; then
        echo "[INFO] Archiving existing log file $file as archived-on-${_start_date}-$file   ..."
        mv $file archived-on-${_start_date}-$file
        echo "[INFO] Done."
      fi
    done
    cd -
  fi
}

# $1 : Startup time
# $2 : End time
delay() {
  if [ $# -lt 2 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function delay !"
    exit 1;
  fi
  local _start=$1
  local _end=$2
  echo "$(( (_end - _start)/3600 )) hour(s) $(( ((_end - _start) % 3600) / 60 )) minute(s) $(( (_end - _start) % 60 )) second(s)"
}

# $1 : Message
# $2 : Startup time
# $3 : End time
display_delay() {
  if [ $# -lt 3 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function display_delay !"
    exit 1;
  fi
  echo "[INFO] $1: $(delay $2 $3) ."
}

#
# Replace in file $1 the value $2 by $3
#
replace_in_file() {
  local _tmpFile=$(mktemp ${TMP_DIR}/replace.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
  mv $1 ${_tmpFile}
  sed "s|$2|$3|g" ${_tmpFile} > $1
  rm ${_tmpFile}
}

# The function computes the UTC date and time from now with a given delay in minutes
# $1 The delay in minutes
computes_operation_utc_date_and_time() {
  local _delay=$1
  YEAR=`date -u -d "$(date) ${_delay} minutes" +%Y`
  MONTH=`date -u -d "$(date) ${_delay} minutes" +%m`
  DAY=`date -u -d "$(date) ${_delay} minutes" +%d`
  HOUR=`date -u -d "$(date) ${_delay} minutes" +%H`
  MIN=`date -u -d "$(date) ${_delay} minutes" +%M`
}

# $1 : Template
# $2 : Recipient
# $3 : Sender
# $4 : Service
# $* : Others templates substitution with XXX=YYY to replace in the template all @XXX@ occurences by YYY
send_mail() {
  local _template=$1; shift;
  local _recipient=$1; shift;
  local _sender=$1; shift;
  local _service=$1; shift;
  local _message=$(mktemp ${TMP_DIR}/email.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
  local _date=`date "+%Y-%m-%d"`
  cp ${_template} ${_message}
  replace_in_file ${_message} "@SERVICE@" ${_service}
  replace_in_file ${_message} "@SENDER@"  ${_sender}
  replace_in_file ${_message} "@RECIPIENT@"  ${_recipient}
  for p in "$@";
  do
    replace_in_file ${_message} "@${p%%=*}@" "${p##*=}"
  done;
  cat ${_message} | sendmail -t
  rm -f ${_message}
}
