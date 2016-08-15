#!/bin/bash

MASTER_CONF=master-config
REGISTRY_CONF=registry-config
ROUTE=$2

function config {
  mkdir -p ${MASTER_CONF}
  mkdir -p ${REGISTRY_CONF}
  docker run \
  -it --rm \
  -u root \
  -v `pwd`/${MASTER_CONF}:/var/lib/openshift/openshift.local.config/master \
  aweiteka/origin-nonroot \
  start master --master https://localhost:443 --public-master https://${ROUTE}:443 --write-config /var/lib/openshift/openshift.local.config/master

  cp `pwd`/${MASTER_CONF}/ca.crt `pwd`/${REGISTRY_CONF}/
  cat `pwd`/${MASTER_CONF}/ca.crt > `pwd`/${REGISTRY_CONF}/service-ca.crt
  cat `pwd`/${MASTER_CONF}/service-signer.crt >> `pwd`/${REGISTRY_CONF}/service-ca.crt

  #oc create secret generic master --from-file `pwd`/${MASTER_CONF}
  #oc create secret generic registry --from-file `pwd`/${REGISTRY_CONF}
}

function setup() {
  POD=$1
  CMD="oc exec -it ${POD} -c master"
  ${CMD} oadm registry

  # pause for components to create
  sleep 3
  # we don't need the kubernetes components created during bootstrapping
  ${CMD} oc delete service docker-registry
}

function manual {
  POD=$(oc get pods -l app=atomic-registry --template '{{ $pod := index .items 0}} {{ $pod.metadata.name }}')
  CMD="oc exec -it ${POD} -c master"
  echo "Using pod ${CMD}"
  #set -x
  #${CMD} oc get sa registry --template '{{ $secret := index .secrets 0 }} {{ $secret.name }}'
  #${CMD} oc get secret ${TOKEN_NAME} --template '{{ .data.token }}' | base64 -d
}
function origin {
  docker run \
    -d \
    --name origin \
    -u root \
    -p 8443:8443 \
    -v `pwd`/tmp:/var/lib/openshift/openshift.local.config/master \
    aweiteka/origin-nonroot \
    start master --config /var/lib/openshift/openshift.local.config/master/master-config.yaml
}

function registry {
  docker run \
    -d \
    --name registry \
    -u 1001 \
    -p 5000:5000 \
    -e REGISTRY_HTTP_NET=tcp \
    -e REGISTRY_HTTP_ADDR=:5000 \
    -e KUBERNETES_SERVICE_HOST=localhost \
    openshift/origin-docker-registry
}
#-e OPENSHIFT_CA_DATA="`cat ${MASTER_CONF}/ca.crt`" \

function stop {
  docker stop origin registry
  docker rm origin registry
}

$1
