#! /bin/bash

setup_wsl() {
    echo -e '\e[0;33mSetting up wsl specific stuff\e[0m'

    wslTmpDir=~/tmp/setup-wsl
    windowsUserName=$(powershell.exe '$env:UserName' | sed $'s/\r//')

    if [ ! -d "$wslTmpDir" ]; then
        mkdir --parents $wslTmpDir
    fi

    ## setup WSL config
    (
        echo '[automount]'
        echo 'enabled = true'
        echo 'root = /'
        echo 'options = "metadata"'
    )> "$wslTmpDir/wsl.conf"
    sudo mv "$wslTmpDir/wsl.conf" /etc/wsl.conf

    ## symlink go paths
    if [ ! -d "/c/User/$windowsUserName/go" ]; then
        echo -e '\e[1;33mIt appears Go is not installed in Windows, skipping symlink\e[0m'
    else
        ln -s ~/go "/c/User/$windowsUserName/go"
    fi

    ## Common aliases
    echo "" >> $HOME/.zshrc
    echo '# Aliases to useful Windows apps' >> $HOME/.zshrc
    echo "alias p=\"powershell.exe\"" >> $HOME/.zshrc
    echo "alias docker=\"docker.exe\"" >> $HOME/.zshrc
    echo "alias docker-compose=\"docker-compose.exe\"" >> $HOME/.zshrc

    # setup docker bridge
    # go get -d github.com/jstarks/npiperelay
    # GOOS=windows go build -o "/mnt/c/Users/$windowsUserName/go/bin/npiperelay.exe" github.com/jstarks/npiperelay

    # sudo ln -s "/mnt/c/Users/$windowsUserName/go/bin/npiperelay.exe" /usr/local/bin/npiperelay.exe

    # sudo apt install socat

    # echo '#!/bin/sh' >> ~/docker-relay
    # echo 'exec socat UNIX-LISTEN:/var/run/docker.sock,fork,group=docker,umask=007 EXEC:"npiperelay.exe -ep -s //./pipe/docker_engine",nofork' >> ~/docker-relay
    # chmod +x ~/docker-relay
    # sudo adduser ${USER} docker

    rm -rf $wslTmpDir
}

setup_metal() {
    echo -e '\e[0;33mStarting setup for Linux on base metal\e[0m'

    ## VSCode
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'

    sudo apt-get update
    sudo apt-get install code-insiders -y

    ## linux-surface
    while true; do
        read -p "Setup surface-linux [Yn]?" yn
        yn=${yn-Y}
        case $yn in
            [Yy]* )
                sudo apt install git curl wget sed
                git clone --depth 1 https://github.com/jakeday/linux-surface.git ~/linux-surface
                sudo sh ~/linux-surface/setup.sh
                break;;
            [Nn]* ) break;;
        esac
    done
}

install_shell() {
    echo -e '\e[0;33mSetting up zsh as the shell\e[0m'

    ## zsh
    sudo apt-get install zsh -y

    ### addressing bug https://github.com/robbyrussell/oh-my-zsh/issues/4069#issue-89607351
    ### when installing ohmyzsh
    git config core.autocrlf false

    curl -L http://install.ohmyz.sh | sh
    sudo chsh -s /usr/bin/zsh ${USER}
    wget https://raw.githubusercontent.com/aaronpowell/system-init/master/linux/.zshrc -O ~/.zshrc

    ## tmux
    sudo apt install tmux -y
}

install_docker() {
    echo -e '\e[0;33mSetting up docker\e[0m'

    sudo apt-get update
    sudo apt-get install \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common \
        -y

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    sudo add-apt-repository --yes \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable nightly test"

    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y
}

install_git() {
    echo -e '\e[0;33mInstalling git\e[0m'

    sudo add-apt-repository ppa:git-core/ppa --yes
    sudo apt update
    sudo apt install git -y
    wget https://raw.githubusercontent.com/aaronpowell/system-init/master/common/.gitconfig --output-document ~/.gitconfig
}

install_devtools() {
    echo -e '\e[0;33mInstalling dev software/runtimes/sdks\e[0m'

    ## dotnet
    wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo add-apt-repository universe --yes
    sudo apt-get update
    sudo apt-get install dotnet-sdk-2.2

    ## go
    wget "https://storage.googleapis.com/golang/go$gover.linux-amd64.tar.gz" --output-document "$tmpDir/go.tar.gz"
    sudo tar -C /usr/local -xzf "$tmpDir/go.tar.gz"

    ## Node.js via fnm
    curl https://raw.githubusercontent.com/Schniz/fnm/master/.ci/install.sh | bash

    ## firacode
    sudo add-apt-repository universe
    sudo apt install fonts-firacode -y
}

echo -e '\e[0;33mPreparing to setup a linux machine from a base install\e[0m'

gover=1.11.5
tmpDir=~/tmp/setup-base

if [ ! -d "$tmpDir" ]; then
    mkdir --parents $tmpDir
fi

## General updates
sudo apt-get update
sudo apt-get upgrade -y

## Utilities
sudo apt-get install unzip

install_shell
install_git
install_docker
install_devtools

## install environment-specific stuff
if uname -r | grep -E 'Microsoft$' -q; then
    setup_wsl
else
    setup_metal
fi

rm -rf $tmpDir
