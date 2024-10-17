FROM ghcr.io/coreweave/nccl-tests:12.4.1-cudnn-devel-ubuntu20.04-nccl2.21.5-1-85f9143

USER root

ARG SLURM_TAG=slurm-23.02
ARG GOSU_VERSION=1.11


RUN set -ex \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

# RUN set -ex \ && apt update && apt install wget gcc bzip2 gcc-c++ git  make openssh-server vim-enhanced bash-completion mpitests-openmpi pmix-devel
RUN apt update && apt install -y python3 python3-pip
RUN python3 -m pip install Cython nose

RUN set -x \
&& git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
&& cd slurm \
&& ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
    --with-mysql_config=/usr/bin  --libdir=/usr/lib64 \
&& make install \
&& install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
&& cd .. \
&& rm -rf slurm

RUN apt install -y libmunge-dev libmunge2 munge

RUN mkdir -p /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
        /etc/slurm \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state  \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm \    
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key \
    && useradd -u 1000 rocky \
    && usermod -p '*'  rocky # unlocks account but sets no password

COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN set -x \
    && chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 600 /etc/slurm/slurmdbd.conf

# VOLUME /etc/slurm
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 774 /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]