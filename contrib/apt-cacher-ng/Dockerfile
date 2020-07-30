FROM debian:10.4@sha256:68f4e2259032a4e6f5035804e64438b52af8dd5889528b305b9059183ea4cd2a

VOLUME ["/var/cache/apt-cacher-ng"]
RUN apt-get update && apt-get install -y apt-cacher-ng

EXPOSE 3142
CMD chmod 777 /var/cache/apt-cacher-ng && /etc/init.d/apt-cacher-ng start && tail -f /var/log/apt-cacher-ng/*
