```
./run config
# not mounting dir as RW?
#chmod -R 766 master-config
oc new-app -f templates/combined.yaml
oc exec -it <pod> -c origin-master
# boostrap the registry components using the supported command
# we'll delete the dc and service components later
oadm registry
# pause for components to create
sleep 3
# we don't need the kubernetes components created during bootstrapping
oc delete dc,service docker-registry

TOKEN_NAME=$(oc get sa registry --template '{{ $secret := index .secrets 0 }} {{ $secret.name }}')
oc get secret ${TOKEN_NAME} --template '{{ .data.token }}' | base64 -d > token
exit
# save token value as registry-config/token
```


## Issues

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

1. Need to generate oauth client on origin pod before cockpit is deployed
1. cockpit-kubernetes console not working. Debug downward API with petervo

## Creating the Oauthclient on origin pod

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
