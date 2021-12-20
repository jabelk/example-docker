FROM ubuntu:latest

# Install dependencies
RUN apt-get update \
  && apt-get install -qy default-jdk ant libxml2-utils openssh-server

# Copy NSO installer to container
ARG NSO_INSTALL_FILE
COPY $NSO_INSTALL_FILE /tmp/nso

# Copy scripts
COPY install-nso.sh /tmp/install-nso.sh
COPY run-nso.sh /tmp/run-nso.sh

# Install NSO
RUN /tmp/install-nso.sh

# Expose SSH, HTTP, HTTPS and NETCONF ports
EXPOSE 22 80 443 830 4334

# Source NSO commands
RUN echo 'source /nso-install/ncsrc' >> /root/.bashrc

# Start NSO
CMD ["/tmp/run-nso.sh"]