FROM debian:buster-20200720@sha256:68f4e2259032a4e6f5035804e64438b52af8dd5889528b305b9059183ea4cd2a

ENV DEBIAN_SNAPSHOT=20200726T085317Z
#ENV DEBIAN_URL=http://snapshot.debian.org
ENV DEBIAN_URL=https://github.com/EchterAgo/debian_snapshots/raw/master/snapshot.debian.org

ENV http_proxy=http://ec-apt-cacher-ng-cont:3142/

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8

RUN echo "deb $DEBIAN_URL/archive/debian/$DEBIAN_SNAPSHOT buster main" > /etc/apt/sources.list && \
    echo "deb $DEBIAN_URL/archive/debian-security/$DEBIAN_SNAPSHOT buster/updates main" >> /etc/apt/sources.list && \
    echo "deb $DEBIAN_URL/archive/debian/$DEBIAN_SNAPSHOT buster-updates main" >> /etc/apt/sources.list

# We need to disable the validity time check as package lists are only valid until a certain time.
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/00snapshot && \
    apt-get update -q && \
    apt-get full-upgrade -qy && \
    apt-get install -qy wget make autotools-dev autoconf libtool xz-utils libffi-dev libncurses5-dev libsqlite3-dev \
        libusb-1.0-0-dev libudev-dev gettext pkg-config libdbus-1-3 libpcsclite-dev swig libxkbcommon-x11-0 git \
        zlib1g-dev libfreetype6 libfontconfig1 libssl-dev libssl1.1 && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get autoremove -y && \
    apt-get clean
