#!/bin/bash

MASTER_CONF=master-config
REGISTRY_CONF=registry-config

function config {
  docker run \
  -it --rm \
  -u root \
  -v `pwd`/${MASTER_CONF}:/var/lib/openshift/openshift.local.config/master \
  aweiteka/origin-nonroot \
  start master --master https://localhost:8443 --public-master https://localhost:8443 --write-config /var/lib/openshift/openshift.local.config/master

cat `pwd`/${MASTER_CONF}/ca.crt > `pwd`/${REGISTRY_CONF}/service-ca.crt
cat `pwd`/${MASTER_CONF}/service-signer.crt >> `pwd`/${REGISTRY_CONF}/service-ca.crt

#  chown -R 1001 `pwd`/${MASTER_CONF}
#  chown -R 1001 `pwd`/${REGISTRY_CONF}
  oc create secret generic origin-config --from-file `pwd`/${MASTER_CONF}
  oc create secret generic registry-secret --from-file `pwd`/${REGISTRY_CONF}
}

function setup {
  oadm registry

  # pause for components to create
  sleep 3
  # we don't need the kubernetes components created during bootstrapping
  oc delete dc,service docker-registry
  # Get the service account token for registry to connect to master API
  TOKEN_NAME=$(oc get sa registry --template '{{ $secret := index .secrets 0 }} {{ $secret.name }}')
  oc get secret ${TOKEN_NAME} --template '{{ .data.token }}' | base64 -d > /etc/atomic-registry/serviceaccount/token
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

function hello {
  echo "hello"
}

$1
