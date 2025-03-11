FROM ubuntu:plucky AS base

ARG USERNAME=developer \
    USER_UID=1000 \
    USER_GID=$USER_UID \
    USER_HOME=/home/$USERNAME

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# reference: https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_change-the-uidgid-of-an-existing-container-user
# ********************************************************
# * USER SETTINGS *
# ********************************************************
# Update the user and group names
RUN groupmod --gid $USER_GID --new-name $USERNAME ubuntu \
    && usermod --login $USERNAME --home $USER_HOME --move-home --shell /usr/bin/bash ubuntu \
    && chown -R $USERNAME:$USERNAME $USER_HOME \
    # Add sudo support. Omit if you don't need to install software after connecting.
    && apt update \
    && apt install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME

FROM base AS latest

ARG DOTNET_VERSIONS="6.0 8.0 9.0" \
    NODE_VERSION=22 \
    GO_VERSION=1.23.2 \
    HUGO_VERSION=0.145.0

# git
RUN sudo apt update \
    && sudo apt install -y git \
    && git config --global user.email "mail@joaoopereira.com" \
    && git config --global user.name "joaoopereira" \
    && git config --global core.filemode false \
    && git config --global safe.directory '*' \
    && git config --global core.editor "code --wait"

# utils
RUN sudo apt update \
    && sudo apt install -y curl wget iputils-ping make

# oh-my-bash
RUN sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --prefix=/usr/local \
    && cat /usr/local/share/oh-my-bash/bashrc >> ~/.bashrc \
# set theme
    && sed -i -e 's/OSH_THEME="font"/OSH_THEME="agnoster"/g' ~/.bashrc

# fzf & zoxide
RUN sudo apt update \
    && sudo apt install fzf \
    && sudo curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh \
    && sudo cp $USER_HOME/.local/bin/zoxide /usr/local/bin/zoxide \
    && echo 'eval "$(zoxide init bash)"' >> ~/.bashrc
    
# dotnet
ENV DOTNET_EnableWriteXorExecute=0 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1
RUN sudo apt update \
    && sudo apt -y install libicu-dev \
    && sudo wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && sudo dpkg -i packages-microsoft-prod.deb \
    && sudo rm packages-microsoft-prod.deb \
    && sudo apt update
# Install multiple dotnet versions
RUN for version in $DOTNET_VERSIONS; do \
        sudo apt install -y dotnet-sdk-$version; \
    done

# install node using nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
RUN bash -c "source ~/.nvm/nvm.sh && nvm install $NODE_VERSION && nvm use $NODE_VERSION"

# docker
COPY --from=docker:cli /usr/local/bin/docker /usr/bin/docker
COPY --from=docker:cli /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
COPY --from=docker/buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx
RUN sudo groupadd --gid 988 docker \
    && sudo usermod -aG docker $USERNAME \
    && sudo touch /var/run/docker.sock && sudo chown $USERNAME /var/run/docker.sock

# kubectl
RUN sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
&& sudo chmod +x kubectl \
&& sudo mv kubectl /usr/local/bin/

# helm
RUN sudo curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN sudo wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
    && sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz \
    && sudo rm go${GO_VERSION}.linux-amd64.tar.gz \
    && sudo ln -s /usr/local/go/bin/go /usr/bin/go

RUN sudo wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb \
    && sudo dpkg -i hugo_extended_${HUGO_VERSION}_linux-amd64.deb  \
    && sudo rm hugo_extended_${HUGO_VERSION}_linux-amd64.deb  \
    && sudo apt update \
    && sudo apt install hugo

# testing features
FROM latest AS next