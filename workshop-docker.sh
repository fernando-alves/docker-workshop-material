#!/usr/bin/env bash
set -e

function check_presence {
  [[ -n `which $1` ]]
}

function pull_image {
  docker image pull $1
}

function image_downloaded {
  [[ -n `docker image ls --filter=reference="$1" --format="{{.ID}}"` ]]
}

function ensure_image_is_present {
  if ! image_downloaded $1 ; then
    echo "Pulling image $1"
    pull_image $1
  fi
}

function ensure_brew_is_installed {
  if ! check_presence 'brew' ; then
    echo 'Ops! We need brew installed =('
    echo 'Please execute the following command and try again:'
    echo '  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"'
    exit 1
  fi
}

function install {
  echo "Installing $1"
  `brew cask install $1`
}

function install_if_not_present {
  if check_presence $1 ; then
    echo "Found $1!"
  else
    install $1
  fi
}

function install_docker {
  ensure_brew_is_installed
  install_if_not_present docker
}

function pull_images {
  ensure_image_is_present 'ubuntu:latest'
  ensure_image_is_present 'ubuntu:16.04'
  ensure_image_is_present 'postgres:latest'
}

install_docker
pull_images
