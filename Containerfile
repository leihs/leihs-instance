FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages, including systemd and dbus
RUN apt-get update && apt-get install -y \
  systemd \
  dbus \
  build-essential \
  bzip2 \
  git \
  libffi-dev \
  libncurses5-dev \
  libncursesw5-dev \
  libpq-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  curl \
  python3-dev \
  python3-venv \
  ruby \
  ruby-dev \
  shared-mime-info \
  zlib1g-dev \
  openssh-server \
  libbz2-dev \
  liblzma-dev \
  libgdbm-dev \ 
  libyaml-dev \
  lsof \
  vim \
  && apt-get clean

COPY . /opt/leihs/leihs-instance

# Install asdf
ENV ASDF_DATA_DIR=/opt/asdf-data
ENV ASDF_DIR=/opt/asdf
RUN mkdir -p $ASDF_DATA_DIR && chown -R root:root $ASDF_DATA_DIR

RUN git clone https://github.com/asdf-vm/asdf.git $ASDF_DIR --branch v0.15.0

ENV PATH="$ASDF_DATA_DIR/shims:$ASDF_DIR/bin:$PATH"
RUN echo ". $ASDF_DIR/asdf.sh" >> /etc/profile

# Setup SSH keys and permissions for root
RUN mkdir -p /var/run/sshd /root/.ssh && \
  ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -q -N "" && \
  cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys && \
  chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
  echo "Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile=/dev/null" > /root/.ssh/config && \
  chmod 600 /root/.ssh/config

# Configure SSH server to allow root login and password authentication
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
  echo "AllowUsers root" >> /etc/ssh/sshd_config

# Copy your keyexchange script
COPY keyexchange.sh /usr/local/bin/keyexchange.sh
RUN chmod +x /usr/local/bin/keyexchange.sh
COPY keyexchange.service /etc/systemd/system/keyexchange.service
RUN systemctl enable keyexchange.service

# Expose SSH port
EXPOSE 22

# # disable some of systemd's automatic mounts because they are not needed in a container
RUN ln -sf /dev/null /etc/systemd/system/proc-sys-fs-binfmt_misc.automount && \
  ln -sf /dev/null /etc/systemd/system/sys-kernel-config.mount && \
  ln -sf /dev/null /etc/systemd/system/sys-kernel-debug.mount && \
  ln -sf /dev/null /etc/systemd/system/sys-kernel-tracing.mount

# # Use systemd as entrypoint to have full init system
CMD ["/sbin/init"]
