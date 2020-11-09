FROM bash:4

RUN ln -s /usr/local/bin/bash /bin/bash
RUN ln -s /opt/smash/smash.sh /usr/sbin/smash
COPY . /opt/smash/

WORKDIR /code
ENTRYPOINT ["bash", "/usr/sbin/smash"]
