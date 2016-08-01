# Atomic Registry on OpenShift

Run Atomic Registry as an OpenShift deployment.

**Requirements**

* Access to OpenShift cluster
* **oc** CLI tool

## Deploy

1. `git clone` this repo
1. Create routes for the services

        oc create route passthrough --service master --port 443
        oc create route passthrough --service registry --port 80
        oc get routes
1. Create the configuration using the master route from the previous step.

        ./run.sh config <openshift_route_hostname>
1. Edit **master-config/master-config.yaml** to ensure all instances of bindAddress are using port 443, not 8443

        bindAddress: 0.0.0.0:443
1. Deploy the registry pods and services

        oc new-app -f templates/multi-pod.yaml \
                   -p MASTER_ROUTE_URI=master-<openshift_project>.<openshift_route>
1. Wait for all pods to start.

        oc get pods -w
1. Run these setup commands inside the master container.

        oc get pods
        oc exec -it <registry_pod> bash
        oadm registry
        oc delete dc,service docker-registry
        TOKEN_NAME=$(oc get sa registry --template '{{ $secret := index .secrets 0 }} {{ $secret.name }}')
        oc get secret ${TOKEN_NAME} --template '{{ .data.token }}' | base64 -d
        exit
1. Copy the registry token and save to local file **registry-config/token**, then recreate registry secrets and re-deploy:

        oc delete secret registry
        oc create secret generic registry --from-file registry-config
        oc deploy registry --latest

1. The registry should be deployed at the route

        oc describe route registry

## Issues/TODO

1. Need to generate oauth client on origin pod before cockpit is deployed
1. cockpit-kubernetes console not working. Debug downward API with petervo
1.Registry certs to establish cxn to origin-master
  * ENV vars
        "OPENSHIFT_MASTER":    config.Host,
        "OPENSHIFT_CA_DATA":   string(config.CAData),
        "OPENSHIFT_KEY_DATA":  string(config.KeyData),
        "OPENSHIFT_CERT_DATA": string(config.CertData),
        "OPENSHIFT_INSECURE":  insecure,
    * reference: https://github.com/pweil-/origin/blob/8291d9eb7941a70cec454a9473e86ad37b396a97/pkg/cmd/admin/registry/registry.go#L276-276
    * grab credentials from kubeconfig: oadm registry --credentials=openshift-registry.kubeconfig -o jsonpath={.items[0].spec.template.spec.containers[0].env[0].value}
  * bearer token from service account cannot work since it's based on platform
           oc exec -it origin-nonroot-9-24dav oc create serviceaccount atomicregistry

## Creating the Oauthclient on origin pod

```
echo -e "{ \"kind\": \"OAuthClient\", \"apiVersion\": \"v1\", \"metadata\": { \"name\": \"cockpit-oauth-client\" }, \"secret\": \"userpaMAxjPPo6JmG3YFXEkmx007Qb7xApmu7sWiLsWUrM3WdGvcfooCOb8arXb2TPUB\", \"redirectURIs\": [ \"https://172.30.147.43:8443\" ]  }" | oc create -f -

ORIGIN_MASTER=172.30.147.43 oc new-app --template registry-console -p OPENSHIFT_OAUTH_PROVIDER_URL=https://${ORIGIN_MASTER}:8443,COCKPIT_KUBE_URL=https://${ORIGIN_MASTER},REGISTRY_HOST=${ORIGIN_MASTER}:5000

{
    "kind": "OAuthClient",
    "apiVersion": "v1",
    "metadata": {
        "name": "cockpit-oauth-client",
        "selfLink": "/oapi/v1/oauthclients/cockpit-oauth-client",
        "uid": "667d4284-0ba8-11e6-af3b-fa163ec62e19",
        "resourceVersion": "118",
        "creationTimestamp": "2016-04-26T12:14:18Z",
        "labels": {
            "createdBy": "registry-console-template"
        },
        "annotations": {
            "openshift.io/generated-by": "OpenShiftNewApp"
        }
    },
    "secret": "userpaMAxjPPo6JmG3YFXEkmx007Qb7xApmu7sWiLsWUrM3WdGvcfooCOb8arXb2TPUB",
    "redirectURIs": [
        "https://10.3.9.225"
    ]
}
```
