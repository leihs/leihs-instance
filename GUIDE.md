# **leihs** Hosting Guide

_For more details, see [`leihs_deploy` Project](https://github.com/leihs/leihs_deploy)
and the [general **leihs** Documentation](https://github.com/leihs/leihs/wiki)_

---

## setup & install

1. ["Fork" this repository on github](https://github.com/leihs/leihs-instance/fork)
   _(only required if you want to receive updates as Pull Requests)_

1. prepare a fresh server running [Ubuntu 18.04.2 LTS (Bionic Beaver)](https://wiki.ubuntu.com/BionicBeaver/ReleaseNotes) or [Debian 9 (stretch)](https://www.debian.org/releases/stretch/), and point a domain name to it. Make sure you can connect as root (or use `sudo` to become root):

   ```sh
   # set connection config (all scripts below expect those exports)
   export LEIHS_HOSTNAME="leihs.example.com"
   export LEIHS_HOST_USER="root"

   # test it
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- 'test $(id -u) -eq 0 && true || sudo true' \
     || echo 'logging in as root user failed, check connection config!' && echo 'OK!'

   # install basic packages
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- \
     'sudo apt update && sudo apt install -fy curl build-essential libssl-dev default-jdk ruby libyaml-dev python2.7 python2.7-dev git libffi-dev'
   ```

1. set up inventory on a computer running Linux or macOS (will be the "control machine").  
   It needs the following software installed: `git`, `python`, `Java 8`, `Ruby 2.3`.

   ```sh
   git clone https://github.com/leihs/leihs-instance "${LEIHS_HOSTNAME}_hosting"
   # OR your fork: git clone git@github.com:yourUserName/leihs-instance "${LEIHS_HOSTNAME}_hosting"
   cd "${LEIHS_HOSTNAME}_hosting"
   sh -c 'git submodule update --init leihs && cd leihs && git submodule update --init --recursive'
   ```

1. Prepare SSL/TLS certificate. To use (the recommended) LetsEncrypt + Certbot, follow the [official instructions](https://certbot.eff.org) to install, then use the following comand to interactively obtain a certificate for the first time. If that worked, automated renewals should be set up as well.

   ```sh
   ssh "${LEIHS_HOST_USER}@${LEIHS_HOSTNAME}" -- \
     "sudo certbot certonly --apache --force-interactive -d '${LEIHS_HOSTNAME}'"
   ```

1. inventory configuration

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

1. install with ansible: `./scripts/deploy`

1. Leihs is now installed on the given hostname.  
   Open it in your browser and use the form to create the first admin user.  
   Add Users and Groups and start using **leihs**! 🎉

<!--
## backup

A `master_secret` was created during the installation and put in a text file
in your repository.
By default it is git-ignored, so it won't be accidentally pushed to a public
host (like GitHub).
You should either back up your local repository with the secret to a secure place;
or use [`git-crypt`](https://www.agwa.name/projects/git-crypt/) to add the
secret to the repository in encrypted form (*recommended*).
-->

## upgrade

1. update `leihs` submodule reference to latest release

   - either by accepting a Pull Request (when enabled)
   - or manually: `./scripts/update_leihs_latest stable`

2. run the deploy playbook again: `./scripts/deploy`

## automatic deployments

**_Prerequisite:_** All changed files (configuration etc) must be committed back into the repository,
so that it can be shared with other computers.
That means `git-crypt` must be set up (see below).

_Note_ that you can use this fork normally, with one caveat:
**don't edit any files that came with this repository**, or you will have to deal with merge conflicts later on!
The only exception is `README.md`, we won't touch it because you'll likely want to customize it.

1. add GPG of your trusted CI machine to the repo:

   ```
   git crypt add-gpg-user ${CI_GPG_KEY_ID}
   ```

2. add SSH public key of CI executor to `authorized_keys` of target server

3. set up your CI to `git crypt unlock` und run the deploy script.
   See `examples/cider-ci.yml` for a working [Cider-CI](https://cider-ci.info) configuration.
