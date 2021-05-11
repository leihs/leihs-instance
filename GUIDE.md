# **leihs** Hosting Guide

_For more details, see [`leihs_deploy` Project](https://github.com/leihs/leihs_deploy)
and the [general **leihs** Documentation](https://github.com/leihs/leihs/wiki)_

---

## setup & install

1. [Generate your own inventory repository by using this template](https://github.com/leihs/leihs-instance/generate)

1. prepare a fresh server running [Ubuntu 18.04.2 LTS (Bionic Beaver)](https://wiki.ubuntu.com/BionicBeaver/ReleaseNotes) or [Debian 10 (buster)](https://www.debian.org/releases/buster/), and point a domain name to it. Make sure you can connect as root (or use `sudo` to become root):

   ```sh
   # set connection config (all scripts below expect those exported variables!)
   export LEIHS_HOSTNAME="leihs.example.com"
   export LEIHS_HOST_USER="root"

   # test it
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- 'test $(id -u) -eq 0 && echo OK || sudo echo OK'

   # ⚠️⚠️⚠️ NOTE: temporary workaround for a needed package that might be missing: ⚠️⚠️⚠️
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- 'apt-get update && apt-get install -fy shared-mime-info'

   ```

1. set up the _inventory_ on your personal computer (the "control machine").
   Install either [`Docker`](https://www.docker.com/products/docker-desktop) _or_ [`ansible`](https://docs.ansible.com/ansible/latest/installation_guide/index.html) and [`ruby`](https://www.ruby-lang.org/en/).

   ```sh
   git clone https://github.com/leihs/leihs-instance "${LEIHS_HOSTNAME}_hosting"
   # OR your fork: git clone git@github.com:yourUserName/leihs-instance "${LEIHS_HOSTNAME}_hosting"
   cd "${LEIHS_HOSTNAME}_hosting"
   sh -c 'git submodule update --init leihs && cd leihs && git submodule update --init --recursive'
   ```

1. Prepare SSL/TLS certificate (mandatory). To use (the free and recommended) LetsEncrypt + Certbot, follow the [official instructions](https://certbot.eff.org) to install, then use the following comand to interactively obtain a certificate for the first time. If that worked, automated renewals should be set up as well.

   ```sh
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- "sudo apt-get update && sudo apt-get install certbot -y python3-certbot-apache"
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- \
     "sudo certbot certonly --apache --force-interactive -d '${LEIHS_HOSTNAME}'"
   ```

1. configure the _inventory_

   ```sh
   # create hosts file
   sh -euc "echo \"$(cat examples/hosts_example)\"" > hosts
   # create host_vars
   sh -euc "echo \"$(cat examples/host_vars_example.yml)\"" > "host_vars/${LEIHS_HOSTNAME}.yml"
   ```

   - edit global config in file `group_vars/leihs_server.yml`
   - edit per-host config in file `host_vars/${LEIHS_HOSTNAME}.yml`.
     - If a custom TLS certificate is used, the `leihs_virtual_hosts` config from `group_vars` needs to be overwritten here.
   - **commit**: `git add . && git commit -m "inventory config for ${LEIHS_HOSTNAME}"`

1. Run the deploy. This will take quite some time, up to an hour.
   Note that (unlike with previous Leihs releases) by default there will be no compilation happening on the control machine, instead "prebuilt artefacts" are download (though some compilation might still happen on the server on the initial deploy and some updates).
   See the section ["build cache"](#build-cache) for details and ["build from source"](#build-from-source) if you want to do that instead.

   - `./scripts/deploy`
   - or, when using Docker: `./scripts/deploy-from-docker`

1. Leihs is now installed on the given hostname.
   Open it in your browser and use the form to **create the first admin user**.

   Add Users and Groups and start using **leihs**! 🎉

## backup

A `master_secret.txt` file was created during the installation and put in your inventory repository.
By default it is git-ignored, so it won't be accidentally pushed to a public host (like GitHub).
You should either back up your local repository with the secret to a secure place;
or use [`git-crypt`](https://www.agwa.name/projects/git-crypt/) to add the
secret to the repository in encrypted form (_recommended_).

## upgrade

1. update `leihs` submodule reference to latest release

   - or manually: `./scripts/update_leihs_latest stable`

1. check the release notes for needed changes to the inventory and/or pull in the updates from the template repo:

   ```shell
   curl -L https://github.com/leihs/leihs-instance/archive/master.tar.gz | tar -xzv --strip=1
   git commit --all -m 'update inventory from upstream'
   ```

1. run the deploy playbook again:
   - `./scripts/deploy-from-docker`
   - or, when not using Docker: `./scripts/deploy`

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

For each Leihs release, an archive containing the build artefacts is attached to the corresponding [GitHub release](https://github.com/leihs/leihs/releases).
The default deploy scripts automatically download and extract this to a local directory
and are configured to use this directory as a cache.
If needed, this can also be done manually, or in a shell script as shown below. Make sure to replace the version number in the examples for the one you plan to use (the latest stable release for production or the latest release candidate for testing).

1. go to a release page, e.g. [**_`6.0.0`_**](https://github.com/leihs/leihs/releases/tag/6.0.0)
1. download the archive `build-artefacts.tar.gz` found under "Assets", on the bottom of the page.
1. extract the archive to a directory, e.g. to `~/Downloads/leihs-`**_`6.0.0`_**
1. in the shell, set the `LOCAL_CACHE_DIR` environment variable to the directory where the archive was extracted, before running the deploy.

```sh
LEIHS_VERSION=6.0.0
export LOCAL_CACHE_DIR="/tmp/leihs-${LEIHS_VERSION}"
mkdir -p "$LOCAL_CACHE_DIR"
curl -L "https://github.com/leihs/leihs/releases/download/${LEIHS_VERSION}/build-artefacts.tar.gz" \
   | tar -C "$LOCAL_CACHE_DIR" -xvzf -
```

## build from source

In case you dont want to use the prebuilt artifacts, you can build everythings yourself from source on the "control machine".
You can either setup a build environment manually or use Docker.

The build process depends on several development tools with need to be installed in the right version on the control machine.
We provide a `Dockerfile` so the whole process can take place in an isolated linux container.
**We recommend using `Docker` on machines not normally used for software development.**
_(Note: Docker is only used on your local machine, not on the web server.)_

- with Docker: Install Docker, for example [Docker Desktop](https://www.docker.com/products/docker-desktop)

- manually: Install the following software packages: `git`, `python 2`, `node.js LTS`, `Java 8`, `Ruby 2.3`, .
