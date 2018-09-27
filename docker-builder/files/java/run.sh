#!/bin/bash

set -x

source /etc/profile

MODE=$1

APP=${APP}

JAR_FILE="${APP}.jar"

CONFIG_DIR="properties"

S3_CONFIG_BUCKET=${S3_CONFIG_BUCKET}

VERSION=${VERSION}

TAR_FILE="${VERSION}-encryption-${APP}.tar"

JAVA_OPTS="-Xmx1536m -Xms128m -XX:+PrintFlagsFinal -XX:+PrintGCDetails"

if [ $# -eq 0 ]
  then
    echo "No arguments supplied, starting in dev mode"
    MODE=dev
fi

case $MODE in
  localhost)
    echo "Container starting in localhost environment"
    CONFIG_FILE="${CONFIG_DIR}/docker-localhost.yml"
    ;;
  dev)
    echo "Container starting in development environment"
    CONFIG_FILE="${CONFIG_DIR}/docker.yml"
    ;;
  ci)
    echo "Container starting in ci environment"
    CONFIG_FILE="${CONFIG_DIR}/ci.yml"
    ;;
  qa|stage|prod)
    echo "Container starting in aws environment"
    echo "My config bucket is: " ${S3_CONFIG_BUCKET}
    JAVA_OPTS=${JAVA_OPTS}
    aws s3 cp s3://${S3_CONFIG_BUCKET}/${TAR_FILE} .
    tar xvf ${TAR_FILE}
    CONFIG_FILE="docker.yml"
    sh run-decrypt.sh
    ;;
  *)
    echo "Container running in development environment"
    CONFIG_FILE="${CONFIG_DIR}/docker.yml"
  ;;
esac

echo "Executing command: " java -jar ${JAR_FILE} server ${CONFIG_FILE}
java ${JAVA_OPTS} -jar ${JAR_FILE} server ${CONFIG_FILE}
