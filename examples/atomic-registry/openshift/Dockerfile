FROM openshift/origin

# we cannot access base image VOLUME /var/lib/origin as non-root user
RUN mkdir /var/lib/openshift && \
    chown -R 1001:1001 /var/lib/openshift
USER 1001
ENV KUBECONFIG=/var/lib/openshift/openshift.local.config/master/admin.kubeconfig
WORKDIR /var/lib/openshift
