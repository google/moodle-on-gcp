# Migration recommendations

## 1. Reconfigure Redis mapping within Moodle's admin section

If you're facing slowliness after migrating into your new instance of Moodle in Google Cloud, it might be associated with the loss of mapping to Redis Cache service. 

To reconfigure that mapping manually, please, follow the [instructions described in this document](configuring-redis-cache-with-moodle).

## 2. Run a cron job inside the newly migrated pods

1. First, get pod names by running the following command.

```
kubectl get pods -n moodle
```

2. With Pod's name in your hands, get into the pod's shell by running the following command line.

```
kubectl -n moodle  exec --stdin --tty <POD_NAME> -- /bin/bash
```

3. Once inside the pod, run the following command line to clean up everything inside the pod. You can automate this process in two different ways: 1) running it from a jumpbox virtual machine; 2) running it from pods (root mode) within the cluster. Instructions on how to do so are coming soon.

> This operation can take several minutes depending on the size of the information coming out of moodledata.

```
/opt/bitnami/php/bin/php /opt/bitnami/moodle/admin/cli/cron.php
```