#!/bin/bash

git config --global url."https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.com/".insteadOf "https://gitlab.com/"

mkdir -p ~/.ssh
eval "$(ssh-agent)"
echo "$NERVES_SSH_KEY" > ~/.ssh/id_rsa.pub
echo "$NERVES_GITHUB_KEY" > ~/.ssh/github.key
chmod 600 ~/.ssh/github.key
ssh-add ~/.ssh/github.key
ssh-add -l
ssh-keyscan github.com >> ~/.ssh/known_hosts
mix local.rebar --force
mix local.hex --force
mix archive.install --force hex nerves_bootstrap
mix deps.get --target $MIX_TARGET
