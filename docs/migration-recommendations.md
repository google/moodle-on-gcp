# Migrating from previous Bitnami image to NGINX based image (Recommended)

## 1. Backup your DB and moodle data

In order to proceed it is always a great practice to take backups from both DB and moodle data from time to time.

Make sure that you use a jump server VM that has VPC access to both filestore and database, in order to backup the files accordingly.

You can backup MySQL via `mysqldump` or via Cloud Console.

You can backup Filestore contents via `rsync` or create a backup via Cloud Console for it.

Since most operations are done in command line, `rsync` is easier, but it as alwaays a good idea to also do a backup via Cloud Console to be safe.

## 2. (Optional Step) For a fresh install and you want to start fresh, cleanup everyting Moodze in your current GKE first

From a shell based environment type

```sh
helm delete -n moodle moodle

kubectl delete hpa -n moodle moodle-hpa
```

Optionally run the provided [cleanup script](../0-infra/cleanup-moodle-install.sh) by defining the `FILESTORE_MOUNT` and `MOODLE_ROOT_IN_FILESTORE` env vars in [Env Vars File](../0-infra/envs.sh), as, those are not set in that file originally.

It will do the following tasks for you in automated fashion:
  - Delete your DB schema and create it with a blank one
  - Delete all of your files within the path set in `MOODLE_ROOT_IN_FILESTORE` env vars.
    - **(Note #1: Take extra care here to avoid removing unwanted files)**.
    - **(Note #2: If your `MOODLE_ROOT_IN_FILESTORE` env var is set to nothing, then the value of `FILESTORE_MOUNT` will control`)**.
    - **(Note #3: This will delete both the `moodle`and `moodledata` paths within that `MOODLE_ROOT_IN_FILESTORE` path)**.
  - Delete your latest image from your current Artifact Registry (Docker Image Repository), defaulted to **moodle-nginx** image name.
    - **(Note #1: In order to delete more than one image, it is advisable to do it over Cloud Console (Browser)**.

  **IMPORTANT:** Please note that cleaning these images is only meant to save costs and avoid having old stuff in your Artifact Registry. You don't have to clean it up now, you can do it later too if you prefer.

  ## 3. Build your new nginx based image

  The NGINX provided image will do most of the manual work used to be done in the Bitnami version, so, when building it, make sure to populate the proper configmap values, more on that can be found in its [sample file](../5a-deployment-no-helm/moodle-configmap-nginx-sample.yaml).

  Make sure to leave the env vars blank in the [Dockerfile.nginx](../4-moodle-image-builder/Dockerfile.nginx) file, as, these are left for compatiblity/documentation purposes only, as, in Kubernetes, those env vars will come from its [configmap file](../5a-deployment-no-helm/moodle-configmap-nginx.yaml) and secrets listed in the [raw vanila yaml files (not helm based)](../5a-deployment-no-helm/).

  Once the image is built successfuly, make sure to pick up the whole path to the image, including the Artifact Registry hostname. To make it easier, look over at the docker pull command in the Artifact Registry image details, the whole URL can be picked up from there, including the current tag of the image just built minutes ago.

  - The given full Image URL should look like this: $LOCATION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-nginx:$BUILD_ID

  Edit the [deployment file](../5a-deployment-no-helm/moodle-deployment-nginx.yaml) and update the `image:` entry with your freshly built one, including its tag.

  ## 4. For when you come from a previous Bitnami deployment and you are not doing a fresh install

  If you are migrating from Bitnami, you will need to add dotfiles into moodledata to ensure that Moodle will run an upgrade instead of a fresh install, **this is a really important step**.

  From within the Jump Server VM, create the 2 dotfiles in your `MOODLE_ROOT/moodledata` path, they may look like the entry below:

  ```sh
  touch /mnt/filestore1/moodleroot/moodledata/.moodle-installed
  ```

  If you want to auto upgrade the image on its first run, you can create this dotfile too.

  ```sh
  touch /mnt/filestore1/moodleroot/moodledata/.moodle-autoupgrade
  ```

  If you don't want to auto upgrade the image on its first run, you can run the upgrade command from cli.

  We recommend adding the .moodle-autoupgrade file.

  When editing the [configmap](../5a-deployment-no-helm/moodle-configmap-nginx.yaml) file, ensure that the values you are using, either matches the existing previous version (Bitnami), or if using a fresh install, follow our recommendations in the given documentation [here](../docs/repository-organization.md) and look for the configmap part.

  Once you are ready with these changes you can proceed with running these 5 commands in the given order wirhin the raw yaml files folder [../5a-deployment-no-helm/](../5a-deployment-no-helm/):

  - `kubectl apply -f moodle-configmap-nginx.yaml`
  - `kubectl apply -f moodle-externaldb-secret.yaml`
  - `kubectl apply -f moodle-password-secret.yaml`
  - `kubectl apply -f moodle-service.yaml`
  - `kubectl apply -f moodle-deployment-nginx.yaml`

  After this, make sure your POD is running, and **with just a single replica**. Later on you will be able to apply the HPA back on.

  To check that you can issue the following command:

```sh
kubectl get pods -n moodle
```

Or to watch for its status, you can append a -w in the end such as:

```sh
kubectl get pods -n moodle -w
```

To stop watching you can hit Control + C to quit.

When it is all set, you can then tail the pod logs for the running POD such as this:

```sh
kubectl logs -f -n moodle $(k get pods -n moodle -o=name --field-selector=status.phase=Running)
```
**Note that this command wast tested with just 1 replica running. We can't guarantee if it works with more than 1 replica running.**

Within the first run of this deployment, Moodle is either not yet installed into NFS or it is but it is not on its latest version, check `MOODLE_URL` env var value.

Also the NGINX and PHP-FPM files are not yet copied into NFS.

The DB tables may suffer changes or gets created, hence it depends on the initial setup (if you did cleanup), or via Moodle auto-upgrade step.

Wnen running Moodle auto-upgrade, it will put the site into Maintenance mode first, then run the upgrade command, then remove the Maintenance mode afterwards.

Ensure that the upgradability path is doable from the current version of your Moodle setup to the given one you want to upgrade, check Moodle's documentation if necessary.

Most of the setup process is done via [this script here](../4-moodle-image-builder/base/opt/setup_moodle.sh).

As instructed before, we make use of some **dotfiles**, such as **($MOODLE_ROOT/moodledata/.moodle-installed)** to control Moodle's installation state.

In order to make sure that Moodle auto-upgrades itself to the latest release, ensure to create a dotfile such as this **($MOODLE_ROOT/moodledata/.moodle-autoupgrade)**

If those 2 files are in that path, Moodle will auto-upgrade itself to the latest release available.

You can also get the latest tar.gz from MOODLE's github repo and extract it to the `MOODLE_ROOT/moodle` path. This will trigger moodle to ask for an upgrade, or you can run the upgrade cli command on your own, but, that's not our recommended approach.

For moosh (Moodle Shell), we add it to the image as a convenience, and, control its installation state with **($MOODLE_ROOT/moodledata/moosh/.installed)** dotfile.

Note that if errors occur you will have to debug it and ensure that you listed the proper ENV vars in [moodle-configmap-nginx.yaml](../5a-deployment-no-helm/moodle-configmap-nginx.yaml) file.

Some important notes and considerations:

  - **Double down on the attention if you have kept the Bitnami's env vars when upgrading, this is really important**.
  - **You can't change Moodle's admin password and name when keeping old Bitnami setup**.
  - **You may also find some plugins incompatilbity during this step**.
  - **When coming from previous Bitnami's setup, it will only upgrade Moodle's core version**.
  - **It won't adjust your config.php file**.
  - It will improve performance due to PHP8.1 improvements and lighter resource usage of NGINX though.
  - Make sure your existing plugins are compatible with Moodle's latest version or consider removing them before upgrading.

If everything runs fine, you can point your browser to the same value set in `SITE_URL` env var, to browse your moodle installation.

Make sure to use the username set in `MOODLE_USERNAME` env var and the password set in the Kubernetes Secret [moodle-password-secret.yaml](../5a-deployment-no-helm/moodle-password-secret.yaml).

Note #1: On a frehs install, We do install some plugins using `moosh` (Moodle Shell), such as `tool_opcache`, `report_benchmark` and we may introduce others in the future. We also adjust Redis mapping in Application and Session stores.

You can always run moosh from a running container too, just run the following command to exec into a running pod:

```sh
kubectl exec -it -n moodle $(kubectl get pods -n moodle -o=name --field-selector=status.phase=Running) -- /bin/sh
```
**Note that this command wast tested with just 1 replica running. We can't guarantee if it works with more than 1 replica running.**

Once inside that POD, you can run the following commands to install a different plugin with Moosh:

```sh

# update plugins list
sudo -u www moosh --moodle-path=$MOODLE_PATH plugin-list > /dev/null 2>&1

# install given plugin
sudo -u www moosh --moodle-path=$MOODLE_PATH plugin-install -f plugin_name
```
**Note that the value set in `plugin_name` corresponds to the Moodle's plugin directory settings, such as `tool_opcache` or `report_benchmark`, etc**.

The same process can be done to manually run the Moodle upgrade process, such as:

```sh
sudo -u www php81 -d max_input_vars=10000 $MOODLE_PATH/admin/cli/maintenance.php --enable

sudo -u www php81 -d max_input_vars=10000 $MOODLE_PATH/admin/cli/upgrade.php --non-interactive --allow-unstable

sudo -u www php81 -d max_input_vars=10000 $MOODLE_PATH/admin/cli/maintenance.php --disable
```

That's it, hopefully this works for you and don't hesitate to let us know of your success or failures using github issues.
---
# Migration recommendations (Bitnami) (Deprecated)

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