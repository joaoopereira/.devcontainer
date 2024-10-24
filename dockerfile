FROM debian AS latest

ARG DOTNET_VERSION=8.0 \
    NODE_VERSION=22

ARG USERNAME=developer \
    USER_UID=1000 \
    USER_GID=$USER_UID \
    USER_HOME=/home/$USERNAME

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# reference: https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_creating-a-nonroot-user
# ********************************************************
# * USER SETTINGS *
# ********************************************************
# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /usr/bin/bash \
    && groupadd --gid 988 docker \
    && usermod -aG docker $USERNAME \
    # Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME

RUN sudo apt update

# git
RUN sudo apt install -y git \
    && git config --global user.email "mail@joaoopereira.com" \
    && git config --global user.name "joaoopereira" \
    && git config --global core.filemode false \
    && git config --global safe.directory '*' \
    && git config --global core.editor "code --wait"

# utils
RUN sudo apt install -y curl wget iputils-ping

# oh-my-bash
RUN sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --prefix=/usr/local \
    && cat /usr/local/share/oh-my-bash/bashrc >> ~/.bashrc \
# set theme
    && sed -i -e 's/OSH_THEME="font"/OSH_THEME="agnoster"/g' ~/.bashrc

# fzf & zoxide
RUN sudo apt install fzf \
    && sudo curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh \
    && sudo cp $USER_HOME/.local/bin/zoxide /usr/local/bin/zoxide \
    && echo 'eval "$(zoxide init bash)"' >> ~/.bashrc

# dev-utils
RUN sudo apt install -y make
    
# dotnet
ENV DOTNET_EnableWriteXorExecute=0 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1
RUN sudo apt -y install libicu-dev \
    && sudo wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && sudo dpkg -i packages-microsoft-prod.deb \
    && sudo rm packages-microsoft-prod.deb \
    && sudo apt update \
    && sudo apt install -y dotnet-sdk-$DOTNET_VERSION

# install node using nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
RUN bash -c "source ~/.nvm/nvm.sh && nvm install $NODE_VERSION && nvm use $NODE_VERSION"

# docker
COPY --from=docker:cli /usr/local/bin/docker /usr/bin/docker
COPY --from=docker:cli /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
COPY --from=docker/buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx
RUN sudo touch /var/run/docker.sock && sudo chown $USERNAME /var/run/docker.sock

# kubectl
RUN sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
&& sudo chmod +x kubectl \
&& sudo mv kubectl /usr/local/bin/

# helm
RUN sudo curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# testing features
FROM latest AS next

RUN sudo apt install -y hugo