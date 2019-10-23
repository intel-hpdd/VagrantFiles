# Vagrantfiles

## Setup IML with Vagrant and VirtualBox

The IML Team typically uses [Vagrant](https://www.vagrantup.com) and [VirtualBox](https://www.virtualbox.org/wiki/Downloads) for day to day development tasks. The following guide will provide an overview of how to setup a development environment from scratch and assumes macos as the backing host platform.

1. Install Homebrew

   [Homebrew](https://brew.sh/) provides a package manager for macos. We will use this to install dependencies in the following steps. See the [Homebrew](https://brew.sh) website for installation instructions.

1. Install Vagrant and VirtualBox

   Using the `brew cask` command:

   ```sh
   brew cask install vagrant virtualbox
   ```

1. Create the default hostonlyif needed by the cluster:

   ```sh
   VBoxManage hostonlyif create
   ```

1. Clone the [Vagrant repo](https://github.com/whamcloud/Vagrantfiles) from Github:

   ```sh
   git clone https://github.com/whamcloud/Vagrantfiles.git
   ```

1. cd into the newly created Vagrantfiles directory

1. Bring up the cluster (manager, 2 mds, 2 oss, 2 client nodes)

   ```sh
   vagrant up
   ```

1. You may want the latest packages from upstream repos. If so, run the following provisioner and restart the cluster

   ```sh
   vagrant provision --provision-with=yum-update
   vagrant reload
   ```

1. Install the latest IML from [copr-devel](https://copr.fedorainfracloud.org/coprs/managerforlustre/manager-for-lustre-devel/)

   ```sh
   vagrant provision --provision-with=install-iml-devel
   ```

At this point you should be able to access the IML GUI on your host at https://localhost:8443

From here you can decide what type of setup to run.

- Monitored Ldiskfs:

  ```sh
  vagrant provision --provision-with=install-ldiskfs-no-iml,configure-lustre-network,create-ldiskfs-fs,create-ldiskfs-fs2,mount-ldiskfs-fs,mount-ldiskfs-fs2
  ```

- Monitored ZFS:

  ```sh
  vagrant provision --provision-with=install-zfs-no-iml,configure-lustre-network,create-pools,zfs-params,create-zfs-fs
  ```

- Managed Mode:

  https://whamcloud.github.io/Online-Help/docs/Contributor_Docs/cd_Managed_ZFS.html
