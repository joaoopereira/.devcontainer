ARG DOTNET_VERSION="8.0" \
    NODE_VERSION="22"

FROM debian AS latest

ARG DOTNET_VERSION \
    NODE_VERSION

USER root

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt update

# git
RUN apt install -y git \
    && git config --global user.email "mail@joaoopereira.com" \
    && git config --global user.name "joaoopereira" \
    && git config --global core.filemode false \
    && git config --global safe.directory '*' \
    && git config --global core.editor "code --wait" \
# to be analyzed a better way to store credentials
    && echo 'git config --global credential.helper store && git config --system credential.helper store' >> ~/.bashrc

# utils
RUN apt install -y curl wget iputils-ping

# oh-my-bash
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --prefix=/usr/local \
    && cat /usr/local/share/oh-my-bash/bashrc >> ~/.bashrc \
# set theme
    && sed -i -e 's/OSH_THEME="font"/OSH_THEME="agnoster"/g' ~/.bashrc

# fzf & zoxide
RUN apt install fzf \
    && curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh \
    && cp /root/.local/bin/zoxide /usr/local/bin/zoxide \
    && echo 'eval "$(zoxide init bash)"' >> ~/.bashrc

# dotnet
ENV DOTNET_EnableWriteXorExecute=0 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1
RUN apt -y install libicu-dev \
    && wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt update \
    && apt install -y dotnet-sdk-$DOTNET_VERSION

# install node using nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash \
    && . ~/.nvm/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm use default

# docker
COPY --from=docker:cli /usr/local/bin/docker /usr/bin/docker
COPY --from=docker:cli /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
COPY --from=docker/buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx

# kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
&& chmod +x kubectl \
&& mv kubectl /usr/local/bin/

# helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# testing features
FROM latest AS next
