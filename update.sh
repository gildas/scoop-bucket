#!/usr/bin/env bash

for scoop in *.json; do
  scoop_folder=$(basename $scoop .json)
  scoop_name=$scoop_folder
  [[ $scoop_name == "lv" ]] && scoop_name="bunyan-logviewer"
  echo ">>>>>> Processing scoop $scoop_folder"
  homepage=$(jq -r .homepage $scoop)
  version=$(jq -r .version $scoop)
  source="$GOPATH/src/$(sed -E 's/https:\/\/(.*)/\1/' <<<"$homepage")"
  echo "  Current Version: $version, Home: $homepage"
  echo "  Source: $source"
  if [[ -d $source/.git ]]; then
    new_version=$(git -C $source tag --list | sort --version-sort | tail -1 | sed -e 's/v//')
    if [[ $new_version != $version ]]; then
      echo "  There is a new version: $new_version"
      echo "  Computing new checksums..."
      url_amd64=$(jq -r '.architecture.["64bit"].url' $scoop)
      url_amd64=${url_amd64//$version/$new_version}
      checksum_amd64=$(http --quiet --download GET $url_amd64 | sha256sum | awk '{print $1}')
      url_arm64="https://github.com/gildas/$scoop_folder/releases/download/v$new_version/${scoop_name}-$new_version-windows-arm64.zip"
      url_arm64=$(jq -r '.architecture.arm64.url' $scoop)
      url_arm64=${url_arm64//$version/$new_version}
      checksum_arm64=$(http --quiet --download GET $url_arm64 | sha256sum | awk '{print $1}')
      jq \
        --arg version        $new_version \
        --arg url_amd64      $url_amd64 \
        --arg checksum_amd64 $checksum_amd64 \
        --arg url_arm64      $url_arm64 \
        --arg checksum_arm64 $checksum_arm64 '
        .version = $version |
        .architecture.["64bit"].url  = $url_amd64 |
        .architecture.["64bit"].hash = $checksum_amd64 |
        .architecture.arm64.url      = $url_arm64 |
        .architecture.arm64.hash     = $checksum_arm64
      ' $scoop | sponge $scoop
    else
      echo "  Version has not changed"
    fi
  else
    echo "  $source is not a git folder"
  fi
done
