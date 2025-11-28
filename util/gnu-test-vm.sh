#!/bin/bash
set -eu
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
root_dir=$( cd -- "$script_dir/.." &> /dev/null && pwd )
vm_name="gnu-test-vm"

# Install LIMA
# export LIMA_VERSION="2.0.1"
# curl -fsSL "https://github.com/lima-vm/lima/releases/download/v${LIMA_VERSION}/lima-${LIMA_VERSION}-$(uname -s)-$(uname -m).tar.gz" | sudo tar Cxzvm /usr/local
# curl -fsSL "https://github.com/lima-vm/lima/releases/download/v${LIMA_VERSION}/lima-additional-guestagents-${LIMA_VERSION}-$(uname -s)-$(uname -m).tar.gz" | sudo tar Cxzvm /usr/local
# sudo apt-get install -y --no-install-recommends qemu-system qemu-utils

#limactl delete --yes --force $vm_name
limactl create --yes --plain --name=$vm_name --cpus=5 --disk=40 --memory=5 --network=lima:user-v2 "$root_dir/util/$vm_name.yaml" || true
limactl start --yes $vm_name || true

# setup workspace
export GNU_VERSION=$(grep '^release_tag_GNU=' "$root_dir/util/build-gnu.sh" | cut -d'"' -f2)
mkdir -p "$root_dir/tmp/gnu"
git clone --recurse-submodules https://github.com/coreutils/coreutils.git "$root_dir/tmp/gnu" || true
cd "$root_dir/tmp/gnu"
git fetch --all --tags
git checkout tags/v9.9

rsync -v -a -e "ssh -F /home/martin/.lima/$vm_name/ssh.config" "$root_dir/tmp/gnu" lima-$vm_name:~/
rsync -v -a -e "ssh -F /home/martin/.lima/$vm_name/ssh.config" --exclude "target*" --exclude "tmp"  "$root_dir" lima-$vm_name:~/


limactl shell $vm_name bash -c "cd ~/coreutils && PROFILE=release-small bash util/build-gnu.sh"
limactl shell $vm_name bash -c "cd ~/coreutils && bash util/run-gnu-test.sh tests/id/smack"
#limactl shell $vm_name bash -c "cd ~/coreutils && CI=1 bash util/run-gnu-test.sh run-root tests/df/skip-rootfs"

limactl shell $vm_name bash
