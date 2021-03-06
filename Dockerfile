FROM ubuntu:14.04.3

ENV HOME /root
ENV PATH /usr/local/go/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
ENV GOROOT /usr/local/go
ENV GO_VERSION 1.5.1
ENV CF_VERSION 6.14.0
ENV RTR_VERSION 2.3.0
ENV VAGRANT_VERSION 1.7.4
ENV PACKER_VERSION 0.8.6
ENV BOSH_INIT_VERSION 0.0.77

RUN \
  apt-get -qqy update && \
  apt-get -qqy install software-properties-common && \
  add-apt-repository -y ppa:brightbox/ruby-ng && \
  add-apt-repository -y ppa:git-core/ppa && \
  apt-get -qqy update && \
  apt-get -qqy install \
  build-essential ruby2.2 ruby2.2-dev zlib1g-dev python libssl-dev \
  zip unzip curl wget silversearcher-ag git jq uuid dnsmasq && \
  gem install -q --no-rdoc --no-ri bundler json bosh_cli

RUN \
  cd /usr/local && \
  (curl -L "https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz" | tar -xz)

RUN \
  cd /usr/local/bin && \
  (curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&version=${CF_VERSION}&source=github-rel" | tar -xz)

RUN \
  cd /usr/local/bin && \
  (curl -L "https://github.com/cloudfoundry-incubator/routing-api-cli/releases/download/${RTR_VERSION}/rtr-linux-amd64.tgz" | tar -xz)

RUN \
  wget --quiet "https://dl.bintray.com/mitchellh/vagrant/vagrant_${VAGRANT_VERSION}_x86_64.deb" && \
  dpkg -i "vagrant_${VAGRANT_VERSION}_x86_64.deb" && \
  rm -f "vagrant_${VAGRANT_VERSION}_x86_64.deb" && \
  vagrant plugin install vagrant-aws

RUN \
  wget --quiet "https://dl.bintray.com/mitchellh/packer/packer_${PACKER_VERSION}_linux_amd64.zip" && \
  unzip packer_${PACKER_VERSION}_linux_amd64.zip -d /usr/local/packer && \
  rm -f packer_${PACKER_VERSION}_linux_amd64.zip && \
  cd /usr/local/bin && ln -s /usr/local/packer/* .

RUN \
  wget --quiet "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" && \
  unzip awscli-bundle.zip && \
  ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && \
  rm -rf awscli-bundle.zip awscli-bundle

RUN \
  wget --quiet -O /usr/local/bin/bosh-init "https://s3.amazonaws.com/bosh-init-artifacts/bosh-init-${BOSH_INIT_VERSION}-linux-amd64" && \
  chmod +x /usr/local/bin/bosh-init

RUN \
  mkdir -p $HOME/.ssh && \
  ssh-keyscan github.com >> $HOME/.ssh/known_hosts && \
  git config --global user.email "micropcf-eng@pivotal.io" && \
  git config --global user.name "Concourse CI"

RUN \
  echo "user=root" > /etc/dnsmasq.d/root
