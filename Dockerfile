FROM registry.centos.org/centos:7

RUN echo $'[mariadb]\nname = MariaDB\nbaseurl = http://yum.mariadb.org/10.2/centos7-amd64\nenabled = 1\ngpgcheck = 1' > /etc/yum.repos.d/MariaDB.repo && \
    rpm --import https://yum.mariadb.org/RPM-GPG-KEY-MariaDB && \
    yum -y install --setopt=tsflags=nodocs epel-release && \
    yum -y install --setopt=tsflags=nodocs mariadb-server && \
    yum -y clean all
    
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    mkdir -p /dbhome

ENV DATADIR /dbhome
ENV DBPORT 7775
EXPOSE ${DBPORT}

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/sbin/mysqld", "--user=mysql", "--datadir=/dbhome", "--port=7775", "--console"]
