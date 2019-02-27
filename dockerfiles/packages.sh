#!/bin/bash

set -euf -o pipefail

DEBIAN_FRONTEND=noninteractive
  apt-get update \
  && apt-get upgrade -y \
  &&  DEBIAN_FRONTEND=noninteractive apt-get install -yqq \
      apt-transport-https \
      apt-utils \
      build-essential \
      curl \
      git \
      gnupg2 \
      libc-client-dev \
      openssh-client \
      python \
      python-dev \
      rsync \
      sudo \
      unzip \
      zlib1g-dev \
      mc \
      --no-install-recommends \
&& rm -rf /var/lib/apt/lists/*