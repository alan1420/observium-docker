# Use phusion/baseimage as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
# See https://github.com/phusion/baseimage-docker/blob/master/Changelog.md for
# a list of version numbers.
FROM phusion/baseimage:0.11
MAINTAINER alan14 <rahmadillah.maulana11@gmail.com>

# Set correct environment variables.
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

# Configure user nobody to match unRAID's settings
 RUN \
 usermod -u 99 nobody && \
 usermod -g 100 nobody && \
 usermod -d /home nobody && \
 chown -R nobody:users /home

# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

# Install locales
RUN locale-gen cs_CZ.UTF-8
RUN locale-gen de_DE.UTF-8
RUN locale-gen en_US.UTF-8
RUN locale-gen es_ES.UTF-8
RUN locale-gen fr_FR.UTF-8
RUN locale-gen it_IT.UTF-8
RUN locale-gen pl_PL.UTF-8
RUN locale-gen pt_BR.UTF-8
RUN locale-gen ru_RU.UTF-8
RUN locale-gen sl_SI.UTF-8
RUN locale-gen uk_UA.UTF-8

RUN rm /etc/apt/sources.list

COPY sources.list /etc/apt/sources.list

# Install Observium prereqs
RUN apt-get update && apt-get upgrade -y
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends wget php php-cgi php-common php-curl mariadb-client \
	  php-mbstring php-gd php-mysql php-gettext php-bcmath \
	  php-imap php-json php-xml php-snmp php-fpm php-zip \
      php-pear snmp fping python-mysqldb rrdtool subversion whois mtr-tiny at \
      nmap ipmitool graphviz imagemagick nginx \
      wget pwgen at libvirt-bin && \
    apt-get update -q -y

#Stop nginx for configuration
RUN /etc/init.d/nginx stop

RUN mkdir -p /opt/observium/firstrun /opt/observium/logs /opt/observium/rrd /config && \
    cd /opt && \
    wget http://www.observium.org/observium-community-latest.tar.gz && \
    tar zxvf observium-community-latest.tar.gz && \
    rm observium-community-latest.tar.gz

COPY firstrun.sh /etc/my_init.d/firstrun.sh
RUN chmod +x /etc/my_init.d/firstrun.sh && \
    chown -R nobody:users /opt/observium && \
    chmod 755 -R /opt/observium && \
    chown -R nobody:users /config && \
    chmod 755 -R /config && \
    chown -R nobody:users /etc/mysql

# Configure nginx to serve Observium app
COPY nginx-observium /etc/nginx/conf.d/observium.conf


# Setup Observium cron jobs
COPY cron-observium /etc/cron.d/observium
RUN chmod 744 /etc/cron.d/observium

EXPOSE 8888/tcp

VOLUME ["/config","/opt/observium/logs","/opt/observium/rrd"]

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
