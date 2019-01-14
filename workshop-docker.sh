#!/usr/bin/env bash
set -euf -o pipefail

function in_color {
  tput -Txterm setaf ${1}; echo -e ${2}; tput -Txterm sgr0;
}

function error { 
  in_color 1 "${1}"
}
function warning { 
  in_color 3 "${1}" 
}
function notice { 
  in_color 6 "${1}"
}

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
    notice "Pulling image $1"
    pull_image $1
  else
    notice "Found image $1!"
  fi
}

function ensure_brew_is_installed {
  if ! check_presence 'brew' ; then
    error 'Ops! We need brew installed =('
    error 'Please execute the following command and try again:'
    error '  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"'
    exit 1
  fi
}

function install {
  notice "Installing $1"
  `brew cask install $1`
}

function install_if_not_present {
  if check_presence $1 ; then
    notice "Found $1!"
  else
    install $1
  fi
}

function setup_docker {
  ensure_brew_is_installed
  install_if_not_present docker
}

function ensure_docker_is_running {
  if ! docker info &> /dev/null ; then
    error 'It looks Docker is not started.'
    error 'Please start the server and run this script again.'
    exit 1
  fi
}

function pull_images {
  ensure_docker_is_running
  ensure_image_is_present 'ubuntu:18.04'
}

function redis_notice {
  if check_presence 'redis-cli' ; then
    warning 'It looks like you have redis installed.'
    warning 'Please make sure the server is not running before the workshop.'
  fi
}

function nodejs_notice {
  if ! check_presence 'node' ; then
    error 'It looks like dont have node installed.'
    error 'Please install it before the workshop. It can be done via: brew install node'
    exit 1
  fi
}

setup_docker
pull_images
redis_notice
nodejs_notice

notice 'All set!'
