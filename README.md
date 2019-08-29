# Create a Virtual HPC Storage Cluster with Vagrant

## Introduction

Vagrant is a powerful platform for programmatically creating and managing virtual machines. It is easy to install and is capable of supporting multiple virtual machine platforms, including VirtualBox, HyperV and VMWare. Additional VM providers can be added by way of plugins. Vagrant is also largely platform-neutral: it can run on Windows, Mac and Linux.

More information about Vagrant is available here:

<https://www.vagrantup.com/>

This article describes how to use Vagrant to very quickly establish a virtual HPC cluster on a single host suitable for use as a testbed for Lustre or as a training environment. This is intended as a platform for learning about how Lustre works, evaluating features, compiling packages, developing software, testing processes and patches.

## Prerequisites

The Vagrant project has comprehensive documentation covering installation requirements, available here:

<https://www.vagrantup.com/docs/>

The platform used in this document is based on Fedora 25 and Oracle's VirtualBox. The target machine needs enough storage capacity to accommodate the virtual machines that will be deployed, which may be several gigabytes each, as well as RAM to allow for multiple VMs to run concurrently.

The default cluster configuration allocates 1GB RAM to the admin node, 512MB to the iSCSI node, and 1GB RAM to each of the metadata servers, object storage servers and clients. The basic cluster has 1 admin node, 2 metadata servers, 2 object storage servers and 2 clients, and so requires 7.5GB RAM available on the host to run well. Naturally, if more VMs are launched, more resources will be consumed.

Memory is probably the single most important resource to optimise. Systems with 16GB or more are recommended. While lots of CPU cores definitely helps, one can be surprisingly frugal. For example, an Intel i5 dual-core NUC with 32GB RAM is capable of supporting 12 VMs concurrently, and is perfectly suitable for the test purposes.

## Installing Vagrant

Vagrant is available for download from the project's site:

<https://www.vagrantup.com/downloads.html>

The CentOS download on the page will also work for Red Hat Enterprise Linux and Fedora OS distributions.

**Note**: There are versions of Vagrant distributed in the package repositories for several OS distributions. The Vagrant project discourages their use in favour of their canonical release, but it may be easier to use the distribution version.

Install the package. For example, for Fedora, RHEL 7, or CentOS 7:

```sh
dnf install \
https://releases.hashicorp.com/vagrant/2.2.5/vagrant_2.2.5_x86_64.rpm
```

This will download and install version `2.2.5`.

Once installed, Vagrant does not require super-user privileges to run.

## Installing VirtualBox

VirtualBox is a virtualization platform available as a free download for multiple operating systems here:

<https://www.virtualbox.org/>

Instructions for installing VirtualBox are available here:

<https://www.virtualbox.org/wiki/Linux_Downloads>

For Fedora users, run the following commands to create a definition for the VirtualBox repository and install the software:

```sh
sudo dnf config-manager --add-repo \
  http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo
sudo dnf --disablerepo=rpmfusion*  install VirtualBox-5.1
```

**Note:** RPM fusion repository carries an unofficial build, so disable it before running an install or update if RPMFusion repositories have been configured on the host.

**Note:** The version number is part of the package name, so must be included. The above example references version 5.1. Check the VirtualBox web site for the latest release information.

## Using the Lustre Vagrant Templates

### Clone the repository

```sh
cd $HOME
git clone git@github.com:whamcloud/Vagrantfiles.git
```

Each subdirectory contains templates for automating the creation of virtual machines.

### Create the Virtual HPC Cluster Project

Create a new project directory:

```sh
mkdir -p $HOME/vagrant-projects/vhpc
```

Copy the `Vagrantfile` into the project directory:

```sh
cp $HOME/Vagrantfiles/Vagrantfile \
$HOME/vagrant-projects/vhpc
```

This Vagrantfile contains the information needed to create a virtual HPC storage cluster comprising:

- 1 iSCSI server
- 1 Admin server
  - Used to host administration and monitoring software
  - The admin server also has a passphraseless SSH key for access to the other nodes in the virtual cluster.
- 2 metadata servers with 4 shared storage volumes, one for the MGS, three for the MDT
  - MGT is 512MB
  - MDTs are 5GB
- 2 object storage servers with 20 shared storage volumes per pair for OSTs
  - Each volume is 5GB. The relatively large number of volumes is useful for creating ZFS pools
- Up to 8 compute nodes / Lustre clients
  - 2 nodes created by default

Each node has a NAT Ethernet device on `eth0` that is used for communication via the host.

There are two additional networks created across the cluster, one intended to simulate a management network used for system monitoring and maintenance, and one to simulate the data network for Lustre and other application-centric traffic. The networks have identical characteristics, differing only by name, and are private to the cluster nodes.

The MDS, OSS and compute nodes are each connected to both the management network and the application data network. The admin server is connected to the management network only.

In addition, each pair of server nodes (MDS, OSS) share a private interconnect intended to simulate an additional dedicated communication ring for use with the Corosync HA software.

The networks are assigned to the node interfaces as follows:

- `eth0`: NAT network to the hypervisor host
  - Present on all nodes
- `eth1`: Management network
  - Present on all nodes
- `eth2`: Application data network
  - Present on MDS, OSS and compute nodes
- `eth3`: "Cross-over" network (Corosync ring 1)
  - Present on MDS and OSS nodes

### Starting and Stopping the Cluster

To create the cluster, run:

```sh
vagrant up
```

To review the status of the VMs in the cluster, run:

```sh
vagrant status
```

To shutdown some or all of the VMs:

```sh
vagrant halt [<vm name>]
```

To stop the whole cluster and destroy the VMs:

```sh
vagrant destroy [-f]
```

### Starting and Stopping Individual Nodes

To start individual node or set of nodes:

```sh
vagrant up <vm name> [<vm name> ...]
```

To stop individual nodes and destroy the instance:

```sh
vagrant destroy [-f] <vm name> [<vm name> ...]
```

### Connecting to the VMs

The admin node is the default cluster node. Connect to it via ssh as follows:

```sh
vagrant ssh
```

In addition, port 8443 on the hypervisor host is mapped via port forwarding to port 443 on the admin VM guest, so that web services running on the admin server can be accessed from outside the VM. Use the hypervisor host network name or IP address and connect to port 8443, and this will redirect a browser or other TCP client to port 443 on the admin VM. The port can be changed by editing the `Vagrantfile` and searching for the following line in the Admin server definition:

```sh
adm.vm.network "forwarded_port", guest: 443, host: 8443
```

To get a list of forwarded ports, run:

```sh
vagrant port <vm name>
```

For example:

```sh
[malcolm@mini vhpc]$ vagrant port adm
The forwarded ports for the machine are listed below. Please note that
these values may differ from values configured in the Vagrantfile if the
provider supports automatic port collision detection and resolution.

    22 (guest) => 2222 (host)
   443 (guest) => 8443 (host)
```

One can also connect to other cluster nodes by specifying the vagrant node name, e.g.:

```sh
vagrant ssh mds1
```

The vagrant node names are:

- adm
- mds[1-2]
- oss[1-2]
- c[1-8]

Run the `vagrant status` command to get a list of the VM definitions. For example:

```sh
[malcolm@mini vhpc]$ vagrant status
Current machine states:

adm                       running (virtualbox)
mds1                      running (virtualbox)
mds2                      running (virtualbox)
oss1                      running (virtualbox)
oss2                      running (virtualbox)
c1                        running (virtualbox)
c2                        running (virtualbox)
c3                        not created (virtualbox)
c4                        not created (virtualbox)
c5                        not created (virtualbox)
c6                        not created (virtualbox)
c7                        not created (virtualbox)
c8                        not created (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```

**Note:** Users are logged into an account called `vagrant` when connecting via SSH. This account has `sudo` privileges for super-user access. While authentication is based on secure keys, the environment is not secure by default, since the keys do not have passphrases.

## Vagrant Command Summary

To get a complete list of available commands:

```sh
vagrant list-commands
```

For example:

```sh
[malcolm@mini demo]$ vagrant list-commands
Below is a listing of all available Vagrant commands and a brief
description of what they do.

box             manages boxes: installation, removal, etc.
cap             checks and executes capability
connect         connect to a remotely shared Vagrant environment
destroy         stops and deletes all traces of the vagrant machine
docker-exec     attach to an already-running docker container
docker-logs     outputs the logs from the Docker container
docker-run      run a one-off command in the context of a container
global-status   outputs status Vagrant environments for this user
halt            stops the vagrant machine
help            shows the help for a subcommand
init            initializes a new Vagrant environment by creating a Vagrantfile
list-commands   outputs all available Vagrant subcommands, even non-primary ones
login           log in to HashiCorp's Atlas
package         packages a running vagrant environment into a box
plugin          manages plugins: install, uninstall, update, etc.
port            displays information about guest port mappings
powershell      connects to machine via powershell remoting
provider        show provider for this environment
provision       provisions the vagrant machine
push            deploys code in this environment to a configured destination
rdp             connects to machine via RDP
reload          restarts vagrant machine, loads new Vagrantfile configuration
resume          resume a suspended vagrant machine
rsync           syncs rsync synced folders to remote machine
rsync-auto      syncs rsync synced folders automatically when files change
share           share your Vagrant environment with anyone in the world
snapshot        manages snapshots: saving, restoring, etc.
ssh             connects to machine via SSH
ssh-config      outputs OpenSSH valid configuration to connect to the machine
status          outputs status of the vagrant machine
suspend         suspends the machine
up              starts and provisions the vagrant environment
validate        validates the Vagrantfile
version         prints current and latest Vagrant version
```

To start a VM:

```sh
vagrant up [<vm name>]
```

To connect to a VM:

```sh
vagrant ssh [<vm name>]
```

To reboot a VM:

```sh
vagrant reload [<vm name>]
```

To stop a VM:

```sh
vagrant halt [<vm name>]
```

**Note:** Don't reboot a VM from within the guest shell. Always use the `vagrant reload` command from the host. Rebooting from within the guest invalidates the SSH configuration and will prevent a connection being made on the next boot.

To get the current status of all VMs in a project:

```sh
vagrant status
```

To suspend the VM:

```sh
vagrant suspend
```

To restore a suspended VM:

```sh
vagrant resume
```

To review the SSH configuration that was used to establish a connection, run this command from the project directory:

```sh
vagrant ssh-config [<vm name>]
```

To tear down and delete the VM:

```sh
vagrant destroy [-f]
```

To get a list of forwarded ports on each host, run:

```sh
vagrant port <vm name>
```

In additon to the built-in commands, Vagrant supports plugins which can add additional functionality. For example, the `vagrant-shell-commander` plugin allows commands to be run on multiple hosts like pdsh except serial.

Refer to the Vagrant documentation for more information on plugins:

<https://www.vagrantup.com/docs/plugins/usage.html>

Refer to the Vagrant documentation for more information:

<https://www.vagrantup.com/docs>
