# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'open3'

# Create a set of /24 networks under a single /16 subnet range
SUBNET_PREFIX = '10.73'.freeze

# Management network for admin comms
MGMT_NET_PFX = "#{SUBNET_PREFIX}.10".freeze

# Lustre / HPC network
LNET_PFX = "#{SUBNET_PREFIX}.20".freeze

ISCI_IP = "#{SUBNET_PREFIX}.40.10".freeze

ISCI_IP2 = "#{SUBNET_PREFIX}.50.10".freeze

Vagrant.configure('2') do |config|
  config.vm.box = 'centos/7'

  config.vm.provider 'virtualbox' do |vbx|
    vbx.linked_clone = true
    vbx.memory = 1024
    vbx.cpus = 4
    vbx.customize ['modifyvm', :id, '--audio', 'none']
  end

  # Create a basic hosts file for the VMs.
  open('hosts', 'w') do |f|
    f.puts <<-__EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

#{MGMT_NET_PFX}.9 b.local b
#{MGMT_NET_PFX}.10 adm.local adm
#{MGMT_NET_PFX}.11 mds1.local mds1
#{MGMT_NET_PFX}.12 mds2.local mds2
#{MGMT_NET_PFX}.21 oss1.local oss1
#{MGMT_NET_PFX}.22 oss2.local oss2
    __EOF
    (1..8).each do |cidx|
      f.puts "#{MGMT_NET_PFX}.3#{cidx} c#{cidx}.local c#{cidx}\n"
    end
  end

  config.vm.provision 'shell', inline: 'cp -f /vagrant/hosts /etc/hosts'

  config.vm.provision 'shell', path: './scripts/disable_selinux.sh'

  system("ssh-keygen -t rsa -m PEM -N '' -f id_rsa") unless File.exist?('id_rsa')

  config.vm.provision 'ssh', type: 'shell', path: './scripts/key_config.sh'

  config.vm.provision 'deps', type: 'shell', inline: <<-SHELL
    yum install -y epel-release
    yum install -y jq htop vim
  SHELL

  config.vm.define 'iscsi' do |iscsi|
    iscsi.vm.hostname = 'iscsi.local'

    iscsi.vm.provider 'virtualbox' do |vbx|
      vbx.memory = 1024
      vbx.cpus = 2
    end

    provision_iscsi_net iscsi, '10'

    iscsi.vm.provider 'virtualbox' do |vbx|
      name = get_vm_name('iscsi')
      create_iscsi_disks(vbx, name)
    end

    iscsi.vm.provision 'bootstrap',
                       type: 'shell',
                       path: './scripts/bootstrap_iscsi.sh',
                       args: [ISCI_IP, ISCI_IP2]
  end

  #
  # Create an admin server for the cluster
  #
  config.vm.define 'adm', primary: true do |adm|
    adm.vm.hostname = 'adm.local'

    adm.vm.network 'forwarded_port', guest: 443, host: 8443

    # Admin / management network
    provision_mgmt_net adm, '10'

    provision_fence_agents adm

    # Install IML onto the admin node
    # Using the mfl devel repo
    adm.vm.provision 'install-iml-devel',
                     type: 'shell',
                     run: 'never',
                     path: 'scripts/install_iml.sh',
                     args: 'https://github.com/whamcloud/integrated-manager-for-lustre/releases/download/5.next/chroma_support.repo'

    # Install IML 5.0 onto the admin node
    # Using the mfl 5.0 repo
    adm.vm.provision 'install-iml-5',
                     type: 'shell',
                     run: 'never',
                     path: 'scripts/install_iml.sh',
                     args: 'https://raw.githubusercontent.com/whamcloud/integrated-manager-for-lustre/v5.0.0/chroma_support.repo'

    # Install IML onto the admin node
    # This requires you have the IML source tree available at
    # /integrated-manager-for-lustre
    adm.vm.provision 'install-iml-local',
                     type: 'shell',
                     run: 'never',
                     path: 'scripts/install_iml_local.sh'
  end

  #
  # Create the metadata servers (HA pair)
  #
  (1..2).each do |i|
    config.vm.define "mds#{i}" do |mds|
      mds.vm.hostname = "mds#{i}.local"

      mds.vm.provider 'virtualbox' do |vbx|
        vbx.name = "mds#{i}"
      end

      provision_lnet_net mds, "1#{i}"

      # Admin / management network
      provision_mgmt_net mds, "1#{i}"

      provision_iscsi_net mds, "1#{i}"

      # Private network to simulate crossover.
      # Used exclusively as additional cluster network
      mds.vm.network 'private_network',
                     ip: "#{SUBNET_PREFIX}.230.1#{i}",
                     netmask: '255.255.255.0',
                     auto_config: false,
                     virtualbox__intnet: 'crossover-net-mds'

      provision_iscsi_client mds, 'mds', i

      provision_zfs_params mds

      provision_mpath mds

      provision_fence_agents mds

      cleanup_storage_server mds

      configure_lustre_network mds

      install_lustre_zfs mds

      install_lustre_ldiskfs mds

      install_zfs_no_iml mds

      install_ldiskfs_no_iml mds

      configure_docker_network mds

      pool_name = (i == 1 ? 'mg' : 'md')

      mds.vm.provision 'create-pools',
                          type: 'shell',
                          run: 'never',
                          inline: <<-SHELL
                            genhostid
                            zpool create #{pool_name}s -o multihost=on /dev/#{pool_name}t
                          SHELL

      if i == 1
        mds.vm.provision 'create-zfs-fs',
                            type: 'shell',
                            run: 'never',
                            inline: <<-SHELL
                              mkfs.lustre --failover 10.73.20.12@tcp --mgs --backfstype=zfs mgs/mgt
                              mkdir -p /lustre/zfsmo/mgs
                              mount -t lustre mgs/mgt /lustre/zfsmo/mgs
                            SHELL

        mds.vm.provision 'create-ldiskfs-fs',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                              mkfs.lustre --mgs --reformat --servicenode=10.73.20.11@tcp --servicenode=10.73.20.12@tcp /dev/mapper/mpatha
                              mkfs.lustre --mdt --reformat --servicenode=10.73.20.11@tcp --servicenode=10.73.20.12@tcp --index=0 --mgsnode=10.73.20.11@tcp --fsname=fs /dev/mapper/mpathb
                         SHELL

        mds.vm.provision 'mount-ldiskfs-fs',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                           mkdir -p /mnt/mgs
                           mkdir -p /mnt/mdt0
                           mount -t lustre /dev/mapper/mpatha /mnt/mgs
                           mount -t lustre /dev/mapper/mpathb /mnt/mdt0
                         SHELL

      else
        mds.vm.provision 'create-zfs-fs',
                            type: 'shell',
                            run: 'never',
                            inline: <<-SHELL
                              mkfs.lustre --failover 10.73.20.11@tcp --mdt --backfstype=zfs --fsname=zfsmo --index=0 --mgsnode=10.73.20.11@tcp mds/mdt0
                              mkdir -p /lustre/zfsmo/mdt0
                              mount -t lustre mds/mdt0 /lustre/zfsmo/mdt0
                            SHELL

        mds.vm.provision 'create-ldiskfs-fs',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                            mkfs.lustre --mdt --reformat --servicenode=10.73.20.11@tcp --servicenode=10.73.20.12@tcp --index=1 --mgsnode=10.73.20.11@tcp --fsname=fs /dev/mapper/mpathc
                         SHELL

        mds.vm.provision 'create-ldiskfs-fs2',
                            type: 'shell',
                            run: 'never',
                            inline: <<-SHELL
                              mkfs.lustre --mdt --reformat --servicenode=10.73.20.11@tcp --servicenode=10.73.20.12@tcp --index=0 --mgsnode=10.73.20.11@tcp --fsname=fs2 /dev/mapper/mpathd
                            SHELL

        mds.vm.provision 'mount-ldiskfs-fs',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                           mkdir -p /mnt/mdt1
                           mount -t lustre /dev/mapper/mpathc /mnt/mdt1
                         SHELL

        mds.vm.provision 'mount-ldiskfs-fs2',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                           mkdir -p /mnt/mdt2
                           mount -t lustre /dev/mapper/mpathd /mnt/mdt2
                         SHELL
      end
    end
  end

  #
  # Create the object storage servers (OSS)
  # Servers are configured in HA pairs
  #
  (1..2).each do |i|
    config.vm.define "oss#{i}",
                     autostart: i <= 2 do |oss|

      oss.vm.hostname = "oss#{i}.local"

      oss.vm.provider 'virtualbox' do |vbx|
        vbx.name = "oss#{i}"
      end

      # Lustre / application network
      provision_lnet_net oss, "2#{i}"

      # Admin / management network
      provision_mgmt_net oss, "2#{i}"

      provision_iscsi_net oss, "2#{i}"

      # Private network to simulate crossover.
      # Used exclusively as additional cluster network
      oss.vm.network 'private_network',
                     ip: "#{SUBNET_PREFIX}.231.2#{i}",
                     netmask: '255.255.255.0',
                     auto_config: false,
                     virtualbox__intnet: 'crossover-net-oss'

      slice = i == 1 ? '0:10' : '10:20'

      provision_iscsi_client oss, 'oss', i

      provision_zfs_params oss

      provision_mpath oss

      provision_fence_agents oss

      cleanup_storage_server oss

      configure_lustre_network oss

      install_lustre_zfs oss

      install_lustre_ldiskfs oss

      install_ldiskfs_no_iml oss

      install_zfs_no_iml oss

      configure_docker_network oss

      oss.vm.provision 'create-pools',
                          type: 'shell',
                          run: 'never',
                          env: { 'device_query' => get_oss_block_devices(slice) },
                          inline: <<-SHELL
                            block_device=$(eval $device_query)
                            genhostid
                            zpool create oss#{i} -o multihost=on raidz2 $block_device
                          SHELL

      if i == 1
        oss.vm.provision 'create-zfs-fs',
                            type: 'shell',
                            run: 'never',
                            inline: <<-SHELL
                              mkfs.lustre --failover 10.73.20.22@tcp --ost --backfstype=zfs --fsname=zfsmo --index=0 --mgsnode=10.73.20.11@tcp oss1/ost00
                              mkdir -p /lustre/zfsmo/ost00
                              mount -t lustre oss1/ost00 /lustre/zfsmo/ost00
                            SHELL

        oss.vm.provision 'create-ldiskfs-fs',
                         type: 'shell',
                         run: 'never',
                         path: 'scripts/create_ldiskfs_fs_osts.sh',
                         args: ['a', 'e', 0, 'fs']

        oss.vm.provision 'mount-ldiskfs-fs',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                          mkdir -p /mnt/ost{0,1,2,3,4}
                          mount -t lustre /dev/mapper/mpatha /mnt/ost0
                          mount -t lustre /dev/mapper/mpathb /mnt/ost1
                          mount -t lustre /dev/mapper/mpathc /mnt/ost2
                          mount -t lustre /dev/mapper/mpathd /mnt/ost3
                          mount -t lustre /dev/mapper/mpathe /mnt/ost4
                         SHELL

        oss.vm.provision 'create-ldiskfs-fs2',
                         type: 'shell',
                         run: 'never',
                         path: 'scripts/create_ldiskfs_fs_osts.sh',
                         args: ['f', 'j', 0, 'fs2']

        oss.vm.provision 'mount-ldiskfs-fs2',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                          mkdir -p /mnt/ost2-{0,1,2,3,4}
                          mount -t lustre /dev/mapper/mpathf /mnt/ost2-0
                          mount -t lustre /dev/mapper/mpathg /mnt/ost2-1
                          mount -t lustre /dev/mapper/mpathh /mnt/ost2-2
                          mount -t lustre /dev/mapper/mpathi /mnt/ost2-3
                          mount -t lustre /dev/mapper/mpathj /mnt/ost2-4
                         SHELL

      else
        oss.vm.provision 'create-zfs-fs',
                            type: 'shell',
                            run: 'never',
                            inline: <<-SHELL
                              mkfs.lustre --failover  10.73.20.21@tcp --ost --backfstype=zfs --fsname=zfsmo --index=1 --mgsnode=10.73.20.11@tcp oss2/ost01
                              mkdir -p /lustre/zfsmo/ost01
                              mount -t lustre oss2/ost01 /lustre/zfsmo/ost01
                            SHELL

        oss.vm.provision 'create-ldiskfs-fs',
                         type: 'shell',
                         run: 'never',
                         path: 'scripts/create_ldiskfs_fs_osts.sh',
                         args: ['k', 'o', 5, 'fs']

        oss.vm.provision 'mount-ldiskfs-fs',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                             mkdir -p /mnt/ost{5,6,7,8,9}
                             mount -t lustre /dev/mapper/mpathk /mnt/ost5
                             mount -t lustre /dev/mapper/mpathl /mnt/ost6
                             mount -t lustre /dev/mapper/mpathm /mnt/ost7
                             mount -t lustre /dev/mapper/mpathn /mnt/ost8
                             mount -t lustre /dev/mapper/mpatho /mnt/ost9
                         SHELL

        oss.vm.provision 'create-ldiskfs-fs2',
                         type: 'shell',
                         run: 'never',
                         path: 'scripts/create_ldiskfs_fs_osts.sh',
                         args: ['p', 't', 5, 'fs2']

        oss.vm.provision 'mount-ldiskfs-fs2',
                         type: 'shell',
                         run: 'never',
                         inline: <<-SHELL
                             mkdir -p /mnt/ost2-{5,6,7,8,9}
                             mount -t lustre /dev/mapper/mpathp /mnt/ost2-5
                             mount -t lustre /dev/mapper/mpathq /mnt/ost2-6
                             mount -t lustre /dev/mapper/mpathr /mnt/ost2-7
                             mount -t lustre /dev/mapper/mpaths /mnt/ost2-8
                             mount -t lustre /dev/mapper/mpatht /mnt/ost2-9
                         SHELL
      end
    end
  end

  # Create a set of compute nodes.
  # By default, only 2 compute nodes are created.
  # The configuration supports a maximum of 8 compute nodes.
  (1..8).each do |i|
    config.vm.define "c#{i}",
                     autostart: i <= 2 do |c|
      c.vm.hostname = "c#{i}.local"

      # Admin / management network
      provision_mgmt_net c, "3#{i}"

      # Lustre / application network
      provision_lnet_net c, "3#{i}"

      c.vm.provision 'install-lustre-client',
                          type: 'shell',
                          inline: <<-SHELL
                            yum-config-manager --add-repo https://downloads.whamcloud.com/public/lustre/lustre-2.12.2/el7/client/
                            yum install -y --nogpgcheck lustre-client
                          SHELL
    end
  end
end

def provision_iscsi_net(config, num)
  config.vm.network 'private_network',
                    ip: "#{SUBNET_PREFIX}.40.#{num}",
                    netmask: '255.255.255.0',
                    virtualbox__intnet: 'iscsi-net'

  config.vm.network 'private_network',
                    ip: "#{SUBNET_PREFIX}.50.#{num}",
                    netmask: '255.255.255.0',
                    virtualbox__intnet: 'iscsi-net'
end

def provision_lnet_net(config, num)
  config.vm.network 'private_network',
                    ip: "#{LNET_PFX}.#{num}",
                    netmask: '255.255.255.0',
                    virtualbox__intnet: 'lnet-net'
end

def provision_mgmt_net(config, num)
  config.vm.network 'private_network',
                    ip: "#{MGMT_NET_PFX}.#{num}",
                    netmask: '255.255.255.0',
                    name: 'vboxnet0'
end

def provision_mpath(config)
  config.vm.provision 'mpath', type: 'shell', inline: <<-SHELL
    yum -y install device-mapper-multipath
    cp /usr/share/doc/device-mapper-multipath-*/multipath.conf /etc/multipath.conf
    systemctl start multipathd.service
    systemctl enable multipathd.service
  SHELL
end

def provision_fence_agents(config)
  config.vm.provision 'fence-agents', type: 'shell', inline: <<-SHELL
    yum install -y epel-release
    yum install -y yum-plugin-copr
    yum -y copr enable managerforlustre/manager-for-lustre-devel
    yum install -y fence-agents-vbox
    yum -y copr disable managerforlustre/manager-for-lustre-devel
  SHELL
end

def provision_zfs_params(config)
  config.vm.provision 'zfs-params',
                      type: 'shell',
                      path: './scripts/zfs_params.sh'
end

def cleanup_storage_server(config)
  config.vm.provision 'cleanup', type: 'shell', run: 'never', inline: <<-SHELL
    yum autoremove -y chroma-agent
    rm -rf /etc/iml
    rm -rf /var/lib/{chroma,iml}
    rm -rf /etc/yum.repos.d/Intel-Lustre-Agent.repo
  SHELL
end

def provision_iscsi_client(config, name, idx)
  config.vm.provision 'iscsi-client', type: 'shell', inline: <<-SHELL
    yum -y install iscsi-initiator-utils lsscsi
    echo "InitiatorName=iqn.2015-01.com.whamcloud:#{name}#{idx}" > /etc/iscsi/initiatorname.iscsi
    iscsiadm --mode discoverydb --type sendtargets --portal #{ISCI_IP}:3260 --discover
    iscsiadm --mode node --targetname iqn.2015-01.com.whamcloud.lu:#{name} --portal #{ISCI_IP}:3260 -o update -n node.startup -v automatic
    iscsiadm --mode node --targetname iqn.2015-01.com.whamcloud.lu:#{name} --portal #{ISCI_IP}:3260 -o update -n node.conn[0].startup -v automatic
    iscsiadm --mode node --targetname iqn.2015-01.com.whamcloud.lu:#{name} --portal #{ISCI_IP2}:3260 -o update -n node.startup -v automatic
    iscsiadm --mode node --targetname iqn.2015-01.com.whamcloud.lu:#{name} --portal #{ISCI_IP2}:3260 -o update -n node.conn[0].startup -v automatic
    systemctl start iscsi
  SHELL
end

def configure_lustre_network(config)
  config.vm.provision 'configure-lustre-network',
                      type: 'shell',
                      run: 'never',
                      path: './scripts/configure_lustre_network.sh'
end

def install_lustre_zfs(config)
  config.vm.provision 'install-lustre-zfs', type: 'shell', run: 'never', inline: <<-SHELL
    yum clean all
    yum install -y --nogpgcheck lustre-zfs
    genhostid
  SHELL
end

def install_lustre_ldiskfs(config)
  config.vm.provision 'install-lustre-ldiskfs',
                      type: 'shell',
                      run: 'never',
                      inline: 'yum install -y lustre-ldiskfs'
end

def install_ldiskfs_no_iml(config)
  config.vm.provision 'install-ldiskfs-no-iml',
                      type: 'shell',
                      run: 'never',
                      path: './scripts/install_ldiskfs_no_iml.sh'
end

def install_zfs_no_iml(config)
  config.vm.provision 'install-zfs-no-iml',
                      type: 'shell',
                      run: 'never',
                      path: './scripts/install_zfs_no_iml.sh'
end

def get_oss_block_devices(slice)
  <<-SHELL
    echo '"Stream"' | socat - UNIX-CONNECT:/var/run/device-scanner.sock | jq -r '.Root .children | map(select(.ScsiDevice | .filesystem_type == "mpath_member")) | map(.ScsiDevice | .children) | flatten | map(.Mpath) | map(.paths | .[2]) | unique | sort | .[#{slice}] | .[]'
  SHELL
end

def get_vm_name(id)
  out, err = Open3.capture2e('VBoxManage list vms')
  raise out unless err.exitstatus.zero?

  path = path = File.dirname(__FILE__).split('/').last
  name = out.split(/\n/)
            .select { |x| x.start_with? "\"#{path}_#{id}" }
            .map { |x| x.tr('"', '') }
            .map { |x| x.split(' ')[0].strip }
            .first

  name
end

# Checks if a scsi controller exists.
# This is used as a predicate to create controllers,
# as vagrant does not provide this
# functionality by default.
def controller_exists(name, controller_name)
  return false if name.nil?

  out, err = Open3.capture2e("VBoxManage showvminfo #{name}")
  raise out unless err.exitstatus.zero?

  out.split(/\n/)
     .select { |x| x.start_with? 'Storage Controller Name' }
     .map { |x| x.split(':')[1].strip }
     .any? { |x| x == controller_name }
end

# Creates a SATA Controller and attaches 10 disks to it
def create_iscsi_disks(vbox, name)
  unless controller_exists(name, 'SATA Controller')
    vbox.customize ['storagectl', :id,
                    '--name', 'SATA Controller',
                    '--add', 'sata']
  end

  dir = "#{ENV['HOME']}/VirtualBox\ VMs/vdisks"
  system 'mkdir', '-p', dir unless File.directory?(dir)

  osts = (1..20).map { |x| ["OST#{x}", '5120'] }

  [
    %w[mgt 512],
    %w[mdt1 5120],
    %w[mdt2 5120],
    %w[mdt3 5120],
  ].concat(osts).each_with_index do |(name, size), i|
    file_to_disk = "#{dir}/#{name}.vdi"
    port = (i + 1).to_s

    unless File.exist?(file_to_disk)
      vbox.customize ['createmedium',
                      'disk',
                      '--filename',
                      file_to_disk,
                      '--size',
                      size,
                      '--format',
                      'VDI',
                      '--variant',
                      'fixed']
    end

    vbox.customize ['storageattach', :id,
                    '--storagectl', 'SATA Controller',
                    '--port', port,
                    '--type', 'hdd',
                    '--medium', file_to_disk,
                    '--device', '0']

    vbox.customize ['setextradata', :id,
                    "VBoxInternal/Devices/ahci/0/Config/Port#{port}/SerialNumber",
                    name.ljust(20, '0')]
  end
end

def configure_docker_network(config)
  config.trigger.before :provision, name: 'configure-docker-network-trigger' do |t|
    t.ruby do |_, _|
      if ARGV[3] == 'configure-docker-network'
        puts 'Copying identify file to job scheduler container.'
        puts `docker ps --format '{{.Names}}' | grep job-scheduler | xargs -I {} docker exec {} sh -c 'mkdir -p /root/.ssh'`
        puts `docker ps --format '{{.Names}}' | grep job-scheduler | xargs -I {} docker cp id_rsa {}:/root/.ssh`
      end
    end
  end

  config.vm.provision 'configure-docker-network', type: 'shell', run: 'never', inline: <<-SHELL
    echo "10.73.10.1 nginx" >> /etc/hosts
  SHELL
end
