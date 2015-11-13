#!/bin/bash

# Don't load it several times
set +u
${_FUNCTIONS_DOCKER_LOADED:-false} && return
set -u

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

function get_port_mapping() {
  docker port $1 | cut -f2 -d":"
}

function get_plf_host() {
  echo $DOCKER_HOST | cut -f2 -d":" | cut -f3 -d"/"
}

function get_plf_url() {
  echo http://$(get_plf_host):$(get_port_mapping $1)
}

function wait_open_port() {
  HOST=$1
  PORT=$2

  max=600
  current=0
  ok=false
  while [ $current -lt $max ]
  do
    current=$((current + 1))

    set +e
    nc -vz $1 $2 2> /dev/null
    if [ $? -eq 0 ]
    then
      ok=true
      current=$max
    else
      echo "DEBUG waiting for ${HOST}:${PORT}" >/dev/stderr
      sleep 1
    fi
    set -e
  done
  if [ $ok == false ]
  then
    echo "ERROR Port $HOST:$PORT not opened after ${max}s"
    return 1
  fi
  return 0
}
