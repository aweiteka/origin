# Development Build Environment

A continuous integration and delivery pipeine in a box to help develop docker images. It uses OpenShift v3 and Jenkins.

## Local Development setup

We're using OpenShift all-in-one container deployment method. See [Getting Started](https://github.com/openshift/origin/#getting-started) instructions.

1. Run OpenShift all-in-one as a container

        docker run -d --name origin --privileged --net=host \
            -v /:/rootfs:ro -v /var/run:/var/run:rw \
            -v /sys:/sys:ro -v /var/lib/docker:/var/lib/docker:rw \
            -v /var/lib/openshift/openshift.local.volumes:/var/lib/openshift/openshift.local.volumes openshift/origin start

1. Enter the container to use the OpenShift CLI.

        $ sudo docker exec -it origin bash

1. Create a registry

        $ oadm registry --credentials=./openshift.local.config/master/openshift-registry.kubeconfig

1. Login using default credentials.

        $ oc login
        Username: test
        Password: test

1. Create a project

        $ oc new-project test

1. Upload the OpenShift template. This will make the template available to instantiate.

        oc create -n test -f https://raw.githubusercontent.com/aweiteka/origin/dev-build-env/examples/dev-build-env/ose-build-template.yaml

 In the [OpenShift web interface](https://localhost:8443) create a new instance of the template you uploaded.

1. Login with credentials test/test
1. Select "test" project
1. Select "Add to Project", "Browse all templates..." and select the "automated-builds" template.
1. Select "Edit Parameters", edit the form and select "Create".

This creates a whole pile of resources: image streams, test deployment, a Jenkin master and the appropriate services and routes to access these resources.

When the Jenkins master is deployed we need to get the service IP address and port.

* OpenShift web UI: navigate to Browse, Services
* CLI: `oc get service jenkins`

**Note**: If you are not on the same host you'll need to [deploy and configure a router](https://docs.openshift.org/latest/admin_guide/install/deploy_router.html).


## Jenkins setup

Now we're ready to create jobs in the Jenkins master. We'll use Jenkins Job builder to define the jobs then render them using a CLI tool.

1. Copy the Jenkins Job Builder template to your source repository and edit.
1. Get the Jenkins pod name

        oc get pods

1. Enter the jenkins container. We'll do this once to gain access to the jenkins-jobs CLI.

        oc exec -it <jenkins_pod_name> bash

1. Edit the jenkins-jobs config file `config/jenkins-jobs.ini` changing the jenkins master service IP address.
1. Add plugins (TODO: bundle these in jenkins master plugin)
  1. In the jenkins master web UI navigate to "manage jenkins" > "Jenkins Plugins" > "Available" tab
  1. Select "git plugin", "git client plugin", "URL SCM plugin", "Poll SCM plugin", "Clone Workspace SCM Plug-in"
1. Run `jenkins-jobs` (TODO: provide jenkins-jobs tool or a way to exec into the jenkins master) to create a whole pile of jenkins jobs.

        jenkins-jobs --conf config/jenkins-jobs.ini --ignore-cache update jenkins-jobs.yaml

1. Using a browser load the Jenkins web UI using the Jenkins service IP address and port. Default credentials are admin/password.


## Bash Notes

```
#!/bin/bash

# OPTIONAL:
# as ose admin (root) add template for all users and projects
oc create -f automated-builds.json -n openshift

# create jenkins master
# see https://github.com/openshift/origin/tree/master/examples/jenkins
oc process -f https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/jenkins-ephemeral-template.json | oc create -f -

# before we create our image build pipeline...
# we need the base image image stream. Using centos here...
oc create -f https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-centos7.json

# as ose user, process template, parameterize, and create
# this may be done via web UI
oc process -f automated-builds.json -v SOURCE_URI=https://github.com/aweiteka/test-isv-auth.git,BASE_DOCKER_IMAGE=centos,BASE_DOCKER_IMAGE_TAG=centos7,BUILD_IMAGE_NAME=acmeapp,NAME=acme,TEST_CMD='/usr/bin/sleep 10' | oc create -f -


### NOTES:

# delete resources in bulk
oc delete all -l template=automated-build

# remote trigger (from jenkins job, for example)
# build, deploy, etc.
curl -X POST <url> [--insecure]

# after test promote image with new tag
# from jenkins?
oc tag ${BUILD_IMAGE_NAME}:${BUILD_IMAGE_TAG} ${BUILD_IMAGE_NAME}:<new-tag>

# export local OSE resources as template
oc export all --all -o json --as-template myproject > myproject.json

# import on another openshift server
oc new-app -f myproject.json
```

## Jenkins Master modifications

1. run as root(?) http://stackoverflow.com/questions/29926773/run-shell-command-in-jenkins-as-root-user
1. list plugins
1. need `oc` CLI. Download release binary and copy `oc` to `/usr/bin/oc`, `chmod 755 /usr/bin/oc`.
1. issues running in OSE. Workaround: run as standalone container image

        sudo docker run -d --name jenkins --privileged -v `pwd`:/root/jjb -p 80:8080 docker-registry.usersys.redhat.com/appinfra-ci/jenkins-master-appinfra
