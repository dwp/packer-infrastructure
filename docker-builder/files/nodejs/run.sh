#!/bin/bash

set -x

source /etc/profile

MODE=$1

APP=${APP}

S3_CONFIG_BUCKET=${S3_CONFIG_BUCKET}

VERSION=${VERSION}

TAR_FILE="${VERSION}-encryption-${APP}.tar"
if [ $# -eq 0 ]
  then
    echo "No arguments supplied, starting in dev mode"
    MODE=dev
fi

case $MODE in
  dev)
    echo "Container starting in development environment"
    START_ARG="start"
    ;;
  ci)
    echo "Container starting in ci environment"
    START_ARG="run ci"
    ;;
  qa|stage|prod)
    echo "Container starting in aws environment"
    echo "My config bucket is: " ${S3_CONFIG_BUCKET}
    aws s3 cp s3://${S3_CONFIG_BUCKET}/${TAR_FILE} .
    tar xvf ${TAR_FILE}
    rm -rf .env
    sh run-decrypt.sh
    mv env .env
    START_ARG="start"
    ;;
  *)
    echo "Container running in development environment"
    START_ARG="start"
  ;;
esac

echo "Executing command: " npm ${START_ARG}
npm ${START_ARG}
