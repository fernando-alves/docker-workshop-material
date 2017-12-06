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
  else
    echo "Found image $1!"
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
  ensure_image_is_present 'fernandoalves/javakihon-gradle:latest'
  ensure_image_is_present 'ubuntu:latest'
}

function postgres_notice {
  if check_presence 'psql' ; then
    echo 'It looks like you have postgres installed.'
    echo 'Please make sure the server is not running before the workshop.'
  fi
}

function make_notice {
  if ! check_presence 'make' ; then
    echo 'It looks like you dont have make installed'
    echo 'You may need to install xcode developer tools. It can be done by running: xcode-select --install'
  fi
}

install_docker
pull_images
postgres_notice
make_notice

echo 'All set!'
