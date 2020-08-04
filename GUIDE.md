# **leihs** Hosting Guide

_For more details, see [`leihs_deploy` Project](https://github.com/leihs/leihs_deploy)
and the [general **leihs** Documentation](https://github.com/leihs/leihs/wiki)_

---

## setup & install

1. ["Fork" this repository on github](https://github.com/leihs/leihs-instance/fork) or [use it as a template](https://github.com/leihs/leihs-instance/generate)

1. prepare a fresh server running [Ubuntu 18.04.2 LTS (Bionic Beaver)](https://wiki.ubuntu.com/BionicBeaver/ReleaseNotes) or [Debian 10 (buster)](https://www.debian.org/releases/buster/), and point a domain name to it. Make sure you can connect as root (or use `sudo` to become root):

   ```sh
   # set connection config (all scripts below expect those exported variables!)
   export LEIHS_HOSTNAME="leihs.example.com"
   export LEIHS_HOST_USER="root"

   # test it
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- 'test $(id -u) -eq 0 && echo OK || sudo echo OK'
   ```

1. set up the *inventory* on your personal computer (the "control machine").

   ```sh
   git clone https://github.com/leihs/leihs-instance "${LEIHS_HOSTNAME}_hosting"
   # OR your fork: git clone git@github.com:yourUserName/leihs-instance "${LEIHS_HOSTNAME}_hosting"
   cd "${LEIHS_HOSTNAME}_hosting"
   sh -c 'git submodule update --init leihs && cd leihs && git submodule update --init --recursive'
   ```

1. install Docker or setup a build environment on the "control machine"

   The build process depends on several development tools with need to be installed in the right version on the control machine.
   We provide a `Dockerfile` so the whole process can take place in an isolated linux container.
   **We recommend using `Docker` on machines not normally used for software development.**
   *(Note: Docker is only used on your local machine, not on the web server.)*

   - with Docker: Install Docker, for example [Docker Desktop](https://www.docker.com/products/docker-desktop)

   - manually: Install the following software packages: `git`, `python 2`, `node.js LTS`, `Java 8`, `Ruby 2.3`, .

1. Prepare SSL/TLS certificate (mandatory). To use (the free and recommended) LetsEncrypt + Certbot, follow the [official instructions](https://certbot.eff.org) to install, then use the following comand to interactively obtain a certificate for the first time. If that worked, automated renewals should be set up as well.

   ```sh
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- "sudo apt-get update && sudo apt-get install certbot -y python-certbot-apache"
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- \
     "sudo certbot certonly --apache --force-interactive -d '${LEIHS_HOSTNAME}'"
   ```

1. configure the *inventory*

   ```sh
   # create hosts file
   sh -euc "echo \"$(cat examples/hosts_example)\"" > hosts
   # create host_vars
   sh -euc "echo \"$(cat examples/host_vars_example.yml)\"" > "host_vars/${LEIHS_HOSTNAME}.yml"
   # create settings.yml file
   sh -euc "echo \"$(cat examples/settings_example.yml)\"" > "settings/${LEIHS_HOSTNAME}.yml"
   ```

   - edit global config in file `group_vars/leihs_server.yml`
   - edit per-host config in file `host_vars/${LEIHS_HOSTNAME}.yml`.
     - <small>If a custom TLS certificate is used, the `leihs_virtual_hosts` config from `group_vars` needs to be overwritten here.</small>
   - edit per-host leihs settings in file `settings/${LEIHS_HOSTNAME}.yml`
   - **commit**: `git add . && git commit -m "inventory config for ${LEIHS_HOSTNAME}"`

1. Run the deploy. This will take quite some time, up to an hour.
   - `./scripts/deploy-from-docker`
   - or, when not using Docker: `./scripts/deploy`

1. Leihs is now installed on the given hostname.
   Open it in your browser and use the form to **create the first admin user**.

   Add Users and Groups and start using **leihs**! 🎉

## backup

A `master_secret.txt` file was created during the installation and put in your inventory repository.
By default it is git-ignored, so it won't be accidentally pushed to a public host (like GitHub).
You should either back up your local repository with the secret to a secure place;
or use [`git-crypt`](https://www.agwa.name/projects/git-crypt/) to add the
secret to the repository in encrypted form (*recommended*).

## upgrade

1. update `leihs` submodule reference to latest release
   - or manually: `./scripts/update_leihs_latest stable`

2. run the deploy playbook again:
   - `./scripts/deploy-from-docker`
   - or, when not using Docker: `./scripts/deploy`

 <!--
get updates to inventory repo:

```shell
git rm -rf --cached .
curl -L https://github.com/leihs/leihs-instance/archive/master.tar.gz | tar -xzv --strip=1
git commit -all -m 'update inventory from upstream'
```
or

```shell
git remote add upstream https://github.com/leihs/leihs-instance
git fetch upstream
```
-->

## automatic deployments

**_Prerequisite:_** All changed files (configuration etc) must be committed back into the repository,
so that it can be shared with other computers.
That means `git-crypt` must be set up (see below).

_Note_ that you can use this fork normally, with one caveat:
**don't edit any files that came with this repository**, or you will have to deal with merge conflicts later on!
The only exception is `README.md`, we won't touch it because you'll likely want to customize it.

1. add GPG of your trusted CI machine to the repo: `git crypt add-gpg-user ${CI_GPG_KEY_ID}`

2. add SSH public key of CI executor to `authorized_keys` of target server

3. set up your CI to `git crypt unlock` und run the deploy script.
   See `examples/cider-ci.yml` for a working [Cider-CI](https://cider-ci.info) configuration.

## build cache

To save time compiling a S3 bucket can be used as a build artefact cache.

For the scripts in this repository, **a public cache is enabled by default**,
which should contain everything needed for the stable versions of leihs.

Flags:

- `-e 'use_s3_build_cache=yes'` to use the cache
- `-e 'force_rebuild=yes'` to always build fresh (and upload to the cache if its enabled)

S3 configuration should be given via environment variables.
Credentials (access id/secret key) are optional, if not given cache will only be read from.

```bash
export S3_CACHE_ENDPOINT="https://s3.example.com"
export S3_CACHE_BUCKET="my-leihs-build-cache"
export S3_ACCESS_KEY_ID="id"
export S3_SECRET_ACCESS_KEY="secret"
```

For testing or private caching, the S3 cache can also be run on the *control machine* (see script for details).

```bash
./scripts/run-s3-cache &
export S3_CACHE_ENDPOINT="http://localhost:9000"
export S3_CACHE_BUCKET="leihs-local-build-cache"
export S3_ACCESS_KEY_ID="leihs-local-build-cache"
export S3_SECRET_ACCESS_KEY="leihs-local-build-cache"
```