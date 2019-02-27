FROM justckr/ubuntu-nginx-php:php7

LABEL maintainer="TeBe" \
      php="7.1" \
      node="11"

# Set correct environment variables
ENV IMAGE_USER=icon
ENV HOME=/home/$IMAGE_USER
ENV COMPOSER_HOME=$HOME/.composer
ENV PATH=$HOME/.yarn/bin:$PATH
ENV GOSS_VERSION="0.3.6"
ENV PHP_VERSION=7.1

USER root

WORKDIR /tmp

#Create icon User
RUN adduser --quiet --disabled-password --shell /bin/bash --home /home/icon -gecos "" icon
RUN echo "icon:n01th1sone!" | chpasswd

RUN mkdir /opt/src
RUN mkdir /home/icon/www
RUN cd /opt/src
RUN chown -R icon:icon /home/icon/www

RUN apt-get install sudo
#Install Google Cloud Components
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get update
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get --only-upgrade install -y google-cloud-sdk

# PHP 7.1+ support
RUN add-apt-repository -y ppa:ondrej/php
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# Install required packages
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip nodejs htop build-essential libssl-dev nginx libfcgi0ldbl php7.1-fpm php7.1-dev php-redis php-igbinary php7.1-gd php7.1-xsl php7.1-curl php7.1-mcrypt php7.1-mbstring php7.1-readline php7.1-xml php7.1-intl php7.1-mysql php7.1-zip php-xml php-redis php-pear php-mbstring php-gd php-mongodb php-imagick php-oauth pkg-config imagemagick xpdf qpdf git-core mc libmagickwand-dev libmagickcore-dev mcrypt curl git libzmq3-dev php-zmq
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get install -y npm

# Change default PHP to 7.1
RUN sudo update-alternatives --set php /usr/bin/php7.1

# Install local redis
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server

# Install redis
RUN printf "\n" | pecl install redis

# Composer
RUN curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# Clone API
RUN cd /home/icon/www
RUN gcloud --verbosity debug source repos clone api --project=ingenious-construction1
RUN cd /home/icon/www/api/
RUN git checkout dev
RUN chown -R icon:icon /home/icon/
RUN runuser -l icon -c 'cd /home/icon/www/api && composer install'

#Add Necessary Repo for GCS Fuse
RUN export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
RUN echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get update
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gcsfuse

#Grab Server Config Files
RUN cd /opt/src
RUN gcloud --verbosity debug source repos clone icon-server-deploy --project=ingenious-construction1
# RUN cp -Rf /opt/src/icon-server-deploy/dev/files/autoload/master.php /home/icon/www/icon-web-app/config/autoload/master.php
# RUN cp -Rf /opt/src/icon-server-deploy/dev/files/autoload/mongo.php /home/icon/www/icon-web-app/config/autoload/mongo.php
# RUN cp -Rf /opt/src/icon-server-deploy/dev/files/autoload/bim-clouds.php /home/icon/www/icon-web-app/config/autoload/bim-clouds.php
RUN cp -Rf /opt/src/icon-server-deploy/dev/config/default /etc/nginx/sites-available/default
RUN cp -Rf /opt/src/icon-server-deploy/shared/config/php.ini /etc/php/7.1/fpm/php.ini
RUN cp -Rf /opt/src/icon-server-deploy/shared/config/nginx.conf /etc/nginx/nginx.conf
RUN cp -Rf /opt/src/icon-server-deploy/shared/config/nginx_global.conf /etc/nginx/nginx_global.conf
RUN cp -Rf /opt/src/icon-server-deploy/shared/config/mime.types /etc/nginx/mime.types
RUN cp -Rf /opt/src/icon-server-deploy/shared/config/php-fpm.conf /etc/php/7.1/fpm/php-fpm.conf
RUN cp -Rf /opt/src/icon-server-deploy/shared/config/www.conf /etc/php/7.1/fpm/pool.d/www.conf
RUN cp -Rf /opt/src/icon-server-deploy/dev/files/.env /home/icon/www/api/.env

#Create file to track host for Load Balancer
RUN sudo bash -c 'echo "$HOSTNAME" >>/home/icon/www/icon-web-app/public/hostname55.html'

# Some node fixes
RUN wget -qO - https://raw.githubusercontent.com/yarnpkg/releases/gh-pages/debian/pubkey.gpg | sudo apt-key add -
RUN sudo DEBIAN_FRONTEND=noninteractive apt-get -y install autoconf libtool pkg-config nasm build-essential

# Install Google Cloud Proxy
RUN cd /opt/src
RUN wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
RUN mv cloud_sql_proxy.linux.amd64 /opt/src/cloud_sql_proxy
RUN mkdir /cloudsql; sudo chmod 777 /cloudsql
RUN chmod +x /opt/src/cloud_sql_proxy

# To install the Stackdriver monitoring agent:
RUN curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
RUN sudo bash install-monitoring-agent.sh

# To install the Stackdriver logging agent:
RUN curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
RUN sudo bash install-logging-agent.sh

#Enable StackDriver for monitoring
RUN (cd /etc/nginx/conf.d/ && curl -O https://raw.githubusercontent.com/Stackdriver/stackdriver-agent-service-configs/master/etc/nginx/conf.d/status.conf)
RUN (cd /opt/stackdriver/collectd/etc/collectd.d/ && curl -O https://raw.githubusercontent.com/Stackdriver/stackdriver-agent-service-configs/master/etc/collectd.d/nginx.conf)

#Enable Servies for Reboot
RUN systemctl enable php7.1-fpm
RUN systemctl enable nginx
RUN chown -R icon:icon /home/icon/

#Start Services
RUN nohup /opt/src/cloud_sql_proxy -dir=/cloudsql -projects=ingenious-construction1 -instances=ingenious-construction1:icon-web-dev-db &
RUN service php7.1-fpm restart
RUN service nginx restart
RUN service stackdriver-agent restart
######################

# Install
# RUN bash ./packages.sh \
#    && adduser --disabled-password --gecos "" $IMAGE_USER && \
#       echo "$IMAGE_USER  ALL = ( ALL ) NOPASSWD: ALL" >> /etc/sudoers && \
#       mkdir -p /var/www/inggithub && \
#       chown -R $IMAGE_USER:$IMAGE_USER /var/www $HOME \
#    && composer global require "hirak/prestissimo:^0.3"  \
#    && rm -rf ~/.composer/cache/* \
#    && chown -R $IMAGE_USER:$IMAGE_USER $COMPOSER_HOME \
#    && curl -fsSL https://goss.rocks/install | GOSS_VER=v${GOSS_VERSION} sh \
#    && cd /var/www/inggithub

# RUN git clone https://github.com/tomaszb1/inggithub.git /var/www/inggithub

# USER $IMAGE_USER

# WORKDIR /var/www/inggithub