#!/bin/bash

set -e

echo "$GITHUB_SSH_KEY" > github_private_key.pem
chmod 0600 github_private_key.pem
eval $(ssh-agent)
ssh-add github_private_key.pem > /dev/null
rm github_private_key.pem

set -x

current_version=$(cat "current-$DISTRO-box-version/number")
echo "current_version: " + $current_version
next_version=$(cat "next-$DISTRO-box-version/number")
echo "next_version: " + $next_version
current_box_commit=$(cat "$DISTRO-box-commit/base-box-commit")
echo "current_box_commit: " + $current_box_commit
next_box_commit=$(git -C "$DISTRO-image-changes" rev-parse -q --verify HEAD)
echo "next_box_commit: " + $next_box_commit

sleep 60

if [[ $current_box_commit == $next_box_commit ]]; then
  echo "$current_box_commit == $next_box_commit"
  echo -n $current_box_commit > box-commit
  echo -n $current_version > box-version-number
  exit 0
fi

echo "$current_box_commit != $next_box_commit"
exit 0

git -C "$DISTRO-image-changes" submodule update --init --recursive

micropcf_json=$(cat "$DISTRO-image-changes/images/micropcf.json")
post_processor_json=`
cat <<EOF
{
  "post-processors": [[
    {
      "type": "vagrant"
    },
    {
      "type": "atlas",
      "only": ["amazon-ebs"],
      "token": "$ATLAS_TOKEN",
      "artifact": "micropcf/$DISTRO",
      "artifact_type": "vagrant.box",
      "metadata": {
        "provider": "aws",
        "version": "$next_version"
      }
    },
    {
      "type": "atlas",
      "only": ["vmware-iso"],
      "token": "$ATLAS_TOKEN",
      "artifact": "micropcf/$DISTRO",
      "artifact_type": "vagrant.box",
      "metadata": {
        "provider": "vmware_desktop",
        "version": "$next_version"
      }
    },
    {
      "type": "atlas",
      "only": ["virtualbox-iso"],
      "token": "$ATLAS_TOKEN",
      "artifact": "micropcf/$DISTRO",
      "artifact_type": "vagrant.box",
      "metadata": {
        "provider": "virtualbox",
        "version": "$next_version"
      }
    }
  ]]
}
EOF
`

echo $micropcf_json | jq '. + '"$post_processor_json" > "$DISTRO-image-changes/images/micropcf.json"

ssh-keyscan $REMOTE_EXECUTOR_ADDRESS >> $HOME/.ssh/known_hosts
remote_path=$(ssh -i remote_executor.pem vcap@$REMOTE_EXECUTOR_ADDRESS mktemp -d /tmp/build-images.XXXXXXXX)

function cleanup { ssh -i remote_executor.pem vcap@$REMOTE_EXECUTOR_ADDRESS rm -rf "$remote_path"; }
trap cleanup EXIT

rsync -a -e "ssh -i remote_executor.pem" "$DISTRO-image-changes" vcap@$REMOTE_EXECUTOR_ADDRESS:$remote_path/
rm -rf "$DISTRO-image-changes" || true

ssh -i remote_executor.pem vcap@$REMOTE_EXECUTOR_ADDRESS <<EOF
  export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
  export ATLAS_TOKEN="$ATLAS_TOKEN"
  cd "$remote_path"
  "$DISTRO-image-changes/images/$DISTRO/build" -var "version=$next_version" -only=$NAMES
EOF

echo -n $next_box_commit > box-commit
echo -n $next_version > box-version-number