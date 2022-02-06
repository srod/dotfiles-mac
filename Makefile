SHELL = /bin/bash
DOTFILES_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
OS := $(shell bin/is-supported bin/is-macos macos linux)
PATH := $(DOTFILES_DIR)/bin:$(PATH)
HOMEBREW_PREFIX := $(shell bin/is-supported bin/is-arm64 /opt/homebrew /usr/local)
export XDG_CONFIG_HOME = $(HOME)/.config
export STOW_DIR = $(DOTFILES_DIR)
export ACCEPT_EULA=Y

.PHONY: test

all: $(OS)

macos: sudo core-macos packages link

linux: core-linux link

core-macos: brew git zsh node

core-linux:
	apt-get update
	apt-get upgrade -y
	apt-get dist-upgrade -f

stow-macos: brew
	eval $$(/opt/homebrew/bin/brew shellenv) && \
	is-executable stow || brew install stow

stow-linux: core-linux
	is-executable stow || apt-get -y install stow

sudo:
ifndef GITHUB_ACTION
	sudo -v
	while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
endif

packages: brew-packages cask-apps node-packages

link: stow-$(OS)
	eval $$(/opt/homebrew/bin/brew shellenv) && \
	for FILE in $$(\ls -A runcom); do if [ -f $(HOME)/$$FILE -a ! -h $(HOME)/$$FILE ]; then \
		mv -v $(HOME)/$$FILE{,.bak}; fi; done
	mkdir -p $(XDG_CONFIG_HOME)
	stow -t $(HOME) runcom
	stow -t $(XDG_CONFIG_HOME) config

unlink: stow-$(OS)
	eval $$(/opt/homebrew/bin/brew shellenv) && \
	stow --delete -t $(HOME) runcom
	stow --delete -t $(XDG_CONFIG_HOME) config
	for FILE in $$(\ls -A runcom); do if [ -f $(HOME)/$$FILE.bak ]; then \
		mv -v $(HOME)/$$FILE.bak $(HOME)/$${FILE%%.bak}; fi; done

brew:
	eval $$(/opt/homebrew/bin/brew shellenv) && \
	is-executable brew || curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash

zsh: ZSH=$(HOMEBREW_PREFIX)/bin/zsh
zsh: SHELLS=/private/etc/shells
zsh: brew
	if ! grep -q $(ZSH) $(SHELLS); then \
		eval $$(/opt/homebrew/bin/brew shellenv) && \
		brew install zsh && \
		sudo append $(ZSH) $(SHELLS) && \
		chsh -s $(ZSH); \
	fi

git: brew
	eval $$(/opt/homebrew/bin/brew shellenv) && \
	brew install git git-extras

node: brew-packages
	is-executable nvm || curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

brew-packages: brew
	eval $$(/opt/homebrew/bin/brew shellenv)  && \
	brew bundle --file=$(DOTFILES_DIR)/install/Brewfile || true

cask-apps: brew
	eval $$(/opt/homebrew/bin/brew shellenv) && \
	brew bundle --file=$(DOTFILES_DIR)/install/Caskfile || true

node-packages: node
	. ${XDG_CONFIG_HOME}/nvm/nvm.sh && nvm install 16 && npm install -g $(shell cat install/npmfile)
