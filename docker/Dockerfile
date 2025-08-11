FROM eclipse-temurin:17-jre-jammy

# Non-root user for NiFi
RUN useradd --no-create-home --shell /bin/false nifi

ARG NIFI_ZIP

RUN apt-get update &&     apt-get install -y --no-install-recommends unzip ca-certificates curl &&     rm -rf /var/lib/apt/lists/*

# Copy the NiFi ZIP built by Maven into the image context
COPY ${NIFI_ZIP} /tmp/

RUN mkdir -p /opt/nifi &&     unzip /tmp/${NIFI_ZIP} -d /opt &&     mv /opt/nifi-*/* /opt/nifi/ &&     rm -rf /tmp/${NIFI_ZIP} &&     chown -R nifi:nifi /opt/nifi

ENV NIFI_HOME=/opt/nifi
ENV PATH=$NIFI_HOME/bin:$PATH
ENV NIFI_WEB_HTTP_PORT=8080

EXPOSE 8080
USER nifi
ENTRYPOINT ["/opt/nifi/bin/nifi.sh", "run"]
