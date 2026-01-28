ARG BASE_TAG=focal-systemd-28.1.1-r1
FROM cruizba/ubuntu-dind:${BASE_TAG}

ENV TZ=Asia/Shanghai
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y \
    curl \
    wget \ 
    vim \ 
    net-tools \
    gcc \
    g++ \
    make \
    git \
    cmake \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY ./config/docker/daemon.json /etc/docker/daemon.json

# java (install as many versions as are available on the given Ubuntu base image)
RUN set -eux; \
    # ensure man directory exists to avoid openjdk postinst errors
    mkdir -p /usr/share/man/man1; \
    apt-get update; \
    apt-get install -y maven; \
    for pkg in openjdk-11-jdk openjdk-17-jdk openjdk-21-jdk; do \
    if apt-cache show "$pkg" >/dev/null 2>&1; then \
    echo "Installing $pkg"; \
    apt-get install -y "$pkg"; \
    else \
    echo "Package $pkg not available, skipping"; \
    fi; \
    done; \
    rm -rf /var/lib/apt/lists/*

# golang
ENV PATH=/usr/local/go/bin:$PATH
ARG GOLANG_VERSION=1.25.3
ENV GOLANG_VERSION=${GOLANG_VERSION}
#https://golang.google.cn/dl/go1.24.5.linux-amd64.tar.gz
ARG GOLANG_DOWNLOAD_URL=https://golang.google.cn/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_URL=${GOLANG_DOWNLOAD_URL}
RUN curl -k -L -o go${GOLANG_VERSION}.linux-amd64.tar.gz ${GOLANG_DOWNLOAD_URL} && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf go${GOLANG_VERSION}.linux-amd64.tar.gz && \
    rm go${GOLANG_VERSION}.linux-amd64.tar.gz && \
    go env -w GOPROXY=https://goproxy.cn,direct && \
    go env -w GO111MODULE=on && \
    go version

# rust
ENV RUSTUP_DIST_SERVER=https://rsproxy.cn
ENV RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh > rustup-init.sh && \
    chmod +x rustup-init.sh && \
    ./rustup-init.sh -y && \
    rm rustup-init.sh && \
    . "$HOME/.cargo/env" && \
    rustc --version && \
    cargo --version
COPY ./config/cargo/config.toml /root/.cargo/config.toml

# git config
RUN git config --global core.longpaths true && \
    git config --global credential.helper store 

# openssh
ARG ROOT_PWD=1234
ENV ROOT_PWD=${ROOT_PWD}
RUN apt-get update && \
    apt-get -y install openssh-server && \
    mkdir -p /var/run/sshd && \
    echo "root:$ROOT_PWD" | chpasswd && \
    rm -rf /var/lib/apt/lists/*
COPY ./config/sshd/sshd_config /etc/ssh/sshd_config
# enable sshd in systemd (so it starts automatically under /sbin/init)
RUN ln -sf /lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service
EXPOSE 22

#install dotnet
RUN wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-sdk-6.0 && \
    rm -rf /var/lib/apt/lists/*

# set locale
RUN apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*
ENV LC_ALL=en_US.UTF-8

RUN curl -fsSL https://apt.cli.rs/pubkey.asc | tee -a /usr/share/keyrings/rust-tools.asc && \
    curl -fsSL https://apt.cli.rs/rust-tools.list | tee /etc/apt/sources.list.d/rust-tools.list && \
    apt install -y ripgrep zoxide && \
    rm -rf /var/lib/apt/lists/* && \
    echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc && \
    echo 'export RUSTUP_DIST_SERVER="https://rsproxy.cn"' >> ~/.bashrc && \
    echo 'export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"' >> ~/.bashrc && \
    echo 'eval "$(zoxide init bash)"' >> ~/.bashrc


ENTRYPOINT [ "/sbin/init", "--log-level=err" ]