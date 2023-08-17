# Building Moodle's container image

This step will set up a cloud build in Google Cloud to generate a new container image for Moodle. For that, we need to edit the information available in the file `cloudbuild-nginx.yaml` or `cloudbuild-bitnami.yaml`, you can use the given shell script files such as `build-nginx-based-image.sh` *(recommended)* or `build-bitnami-based-image.sh` which seats on directory `4-moodle-image-builder`.

The reason we do recommend the NGINX based image is listed below:
 - Adjusted performance tuning on NGINX, php8.1-fpm, Opcache, PHP enabled JIT, etc.
 - Latest Version of Moodle: 4.2.1
 - NGINX itself, lighter httpd server
 - No need for SSL since the termination is done in Ingress.
 - Improved self instalation in first run:
  - Adds cron
  - Moosh utility
  - Uses moosh to install recommended plugins (tool_opcache, report_benchmark)
  - Sets default recommended settings in config.php (Uses Redis as Session Store)
  - Tested with 200K online users along with Redis Enterprise (Require sharding adjustments for better IOPS)
  - Works with Google Cloud MemoryStore (Redis)
  - Can be spreaded into different instances of Google Cloud MemoryStore (Redis) as well, one for each store, session handling, file locks, etc.
  - We are also considering **deprecating** the Bitnami image later on.

1. Let's build the image first. For that, under the `steps` below, update the second line `args` described below with information on your container registry, we recommend using `moodle-nginx` or `moodle-bitnami` as the image name depending on the Moodle flavor you choose to run.

If the desired choice is to go with our recommended updated NGINX based image, then replace `moodle-nginx` in `cloudbuild-nginx.yaml` file if you want a different image name for this build, or, leave just like that.
The same goes for if your choice is to go with the Bitnami based image, replacing the value of `moodle-bitnami` in `cloudbuild-bitnami.yaml` to something you might prefer or, leave it otherwise like that.

So, if NGINX change this:
```
'$LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-nginx:$BUILD_ID',
```
to something like this:
```
'$LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/my-nginx-moodle-image:$BUILD_ID',
```

And if Bitnami's, then:
```
'$LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-bitnami:$BUILD_ID',
```
to something like this:
```
'$LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/my-bitnami-moodle-image:$BUILD_ID',
```

If you're using Google Cloud Artifact Registry (like the example below), that information should be available to you in the context of the service's blade, as depicted by the Figure below.

<p align="center">
    <img src="../img/artifact-registry-connection-info.png">
</p>

If you're using whatever other container image repository, please collect that connection information properly and make sure it can communicate back with the Kubernetes cluster.

For Artifact Registry, the default version of that line should look like the one described below.

If following the recommended NGINX version:
```
args: ['build', '-t', '$LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-nginx:$BUILD_ID', '.', '-f', 'Dockerfile.nginx']
```

Or if using Bitnami's:
```
args: ['build', '-t', '$LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-bitnami:$BUILD_ID', '.', '-f', 'Dockerfile.bitnami']
```

2. Now, the same changes should be made in the push command inside of the `cloudbuild-nginx.yaml` or `cloudbuild-bitnami.yaml` in order to be able to push the image to the correct repository in Artifactory Registry. For that, simply repeat the process described in step 1 for the second `args` line, described below.

If following the recommended NGINX version:
```
args: [
    'push',
    '$LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-nginx:$BUILD_ID'
  ]
```

Or if using Bitnami's:
```
args: [
    'push',
    '$LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-bitnami:$BUILD_ID'
  ]
```

3. Finally, kick off the `build` and `push` process by coming back to the file `infra-creation.sh` within the directory `0-infra` and executing the following command line, placed at the end of the file.

If following the recommended NGINX version:
```
cd ../4-moodle-image-builder && build-nginx-based-image.sh
```

Or if using Bitnami's:
```
cd ../4-moodle-image-builder && build-bitnami-based-image.sh
```

Wait until you get confirmation from the command line the process finished successfully. Additionally, you can head to your image repository and double-check that the image is properly sitting there.

<p align="center">
    <img src="../img/moodle-image-in-container-registry.png">
</p>