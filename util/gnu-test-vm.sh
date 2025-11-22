#!/bin/bash
set -eu

# Install LIMA
# export LIMA_VERSION="2.0.1"
# curl -fsSL "https://github.com/lima-vm/lima/releases/download/v${LIMA_VERSION}/lima-${LIMA_VERSION}-$(uname -s)-$(uname -m).tar.gz" | sudo tar Cxzvm /usr/local
# curl -fsSL "https://github.com/lima-vm/lima/releases/download/v${LIMA_VERSION}/lima-additional-guestagents-${LIMA_VERSION}-$(uname -s)-$(uname -m).tar.gz" | sudo tar Cxzvm /usr/local
# sudo apt-get install -y --no-install-recommends qemu-system qemu-utils


vm_name="gnu-test-vm"

limactl delete --force --yes $vm_name
limactl create --yes --plain --name=$vm_name --cpus=3 --disk=40 --memory=3 --network=lima:user-v2 util/gnu-test-vm.yaml

sudo chmod a+rw /dev/kvm
limactl start $vm_name

#limactl shell $vm_name
#rsync -a -e ssh ../gnu/ lima-$vm_name:~/work/gnu/.
