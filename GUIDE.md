# **leihs** Hosting Guide

*For more details, see [`leihs_deploy` Project](https://github.com/leihs/leihs_deploy)
and the [general **leihs** Documentation](https://github.com/leihs/leihs/wiki)*

---

## setup & install

1. ["Fork" this repository on github](https://github.com/leihs/leihs-instance/fork)
  *(only required if you want to receive updates as Pull Requests)*

1. set up inventory on a computer running Linux or macOS (will be the "control machine").  
   It needs the following software installed: `git`, `ansible`, `Java 8`.
  ```sh
  which ansible-playbook || echo 'install ansible first!'
  git clone git@github:yourUserName/leihs-instance my-leihs
  cd my-leihs
  sh -c 'git submodule update --init leihs && cd leihs && git submodule update --init --recursive'
  ```

1. prepare a server running [Debian `stretch`](https://www.debian.org/releases/stretch/),
  log in as root via SSH and do
  ```
  apt install curl build-essential libssl-dev default-jdk ruby libyaml-dev python2.7 python2.7-dev python-pip git libffi-dev
  ```

1. inventory configuration
  - prepare inventory files
    ```
    # set hostname
    export LEIHS_HOSTNAME="leihs.example.com"
    # create hosts file
    sh -c "echo \"$(cat examples/hosts_example)\"" > hosts
    # create host_vars
    sh -c "echo \"$(cat examples/host_vars_example.yml)\"" > "host_vars/${LEIHS_HOSTNAME}.yml"
    ```
  - edit global config in file `group_vars/leihs.yml`
  - edit per-host config in file `host_vars/${LEIHS_HOSTNAME}.yml`

1. install with ansible: `./scripts/deploy`

<!--
1. setup initial configuration & admin account (choose a better password and save it):
  ```sh
  ansible-playbook -i hosts leihs/deploy/play_first-time-setup.yml -e "admin_password=supersecret"
  ```
-->

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

1. run the setup playbook again: `ansible-playbook -i hosts leihs/deploy/play_setup-and-deploy.yml`

## automatic deployments

***Prerequisite:*** All changed files (configuration etc) must be committed back into the repository,
so that it can be shared with other computers.
That means `git-crypt` must be set up (see below).

*Note* that you can use this fork normally, with one caveat:
**don't edit any files that came with this repository**, or you will have to deal with merge conflicts later on!
The only exception is `README.md`, we won't touch it because you'll likely want to customize it.

1. add GPG of your trusted CI machine to the repo:
  ```
  git crypt add-gpg-user ${CI_GPG_KEY_ID}
  ```

1. add SSH public key of CI executor to `authorized_keys` of target server

1. set up your CI to `git crypt unlock` und run the deploy script.
  See `examples/cider-ci.yml` for a working [Cider-CI](https://cider-ci.info) configuration.

## git-crypt

set up and add master secret:

```sh
which git-crypt || echo 'install `git-crypt` first!'
cp examples/git-crypt/.git{ignore,attributes} .
git commit .gitignore .gitattributes -m 'setup git-crypt'
git crypt init
git crypt add-gpg-user you@example.com
git add master_secret.txt && git commit -m 'add encrypted secret'
git crypt status
```

if needed, set up secret variables:

```sh
# create hosts file
sh -c "echo \"$(cat examples/git-crypt/hosts_example)\"" > hosts
# create host_vars
sh -c "echo \"$(cat examples/git-crypt/group_vars_secret_example.yml)\"" > group_vars/secrets.yml
git add group_vars/secrets.yml && git commit -m 'add encrypted secrets'
git crypt status
```

## HTTPS

Secure Communications for your users (HTTPS) can be enabled
by obtaining a TLS certificate and configure apache to use it.
This can be done easily using `certbot` by [LetsEncrypt](https://letsencrypt.org).


1. Install `certbot`: `sudo apt-get install python-certbot-apache -t jessie-backports`
2. Get cert: `certbot certonly --apache -d leihs.example.com`
3. Configure apache: `certbot run -n --apache --redirect --apache-vhost-root /etc/apache2/leihs -d leihs.example.com`
  - even more secure (SSL Labs `A+` instead of `A`): `certbot run -n --apache --redirect --hsts --uir --strict-permissions --apache-vhost-root /etc/apache2/leihs -d leihs.example.com`

If a certificate set up this way is found on the server, the deploy process will automatically use `certbot` for configuration with recommended settings.
You only have to re-run `certbot` yourself after each deploy if you prefer other settings.
