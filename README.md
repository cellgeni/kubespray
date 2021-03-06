![Kubernetes Logo](https://raw.githubusercontent.com/kubernetes-incubator/kubespray/master/docs/img/kubernetes-logo.png)

Kubernetes Cluster on Sanger Institute OpenStack cloud
======================================================

## Authors

Vladimir Kiselev (@wikiselev), Anton Khodak (@anton-khodak), Stijn van Dongen (@micans), __Theo Barber-Bany__ (@theobarberbany) and __Helen Cousins__ (@HelenCousins)

> Helen and Theo have done most of the heavy lifting work!

## Prerequisites

You will need a Sanger OpenStack account. Consult the [wiki](https://ssg-confluence.internal.sanger.ac.uk/display/OPENSTACK/OpenStack) for information about getting an account and getting started.

If you already have an OpenStack account and forgot your password you can find it by logging in to [Cloudforms](https://cloudforms.internal.sanger.ac.uk/) with your Sanger credentials and going to Services/Catalogs/Reset OpenStack Password. Click the `Order` button and then copy your previous password and click `Cancel`. This password will also be needed in one of the next steps.

## High-level overview of the process

To setup a Kubernetes cluster we will use Terraform and Ansible. Terraform creates instances in OpenStack, along with networks and volumes and all the other fiddly bits required for the Kubernetes cluster. Ansible provisions all the necessary software to those instances.

Both Terraform and Ansible are run from a _deployment machine_ (see below).

All of the software have been nicely packaged into [kubespray](https://github.com/kubernetes-incubator/kubespray) GitHub repository. Here we are using version 2.5.0 of the kubespray, which was obtained by forking the original repository and resetting the head of the repository to the commit before the release of version 2.5.0:
```
git reset --hard 02cd541
git push -f origin master
```

All other changes were introduced by the authors.

## Deployment machine

* For Kubernetes deployment we recommend using `farm4-head1` node of the Sanger farm. It already has all of the required cloud command line interfaces installed for you.

* Download the OpenStack RC File (Identity API v3) and OpenStack RC File (Identity API v2) from [Horizon dashboard](https://zeta.internal.sanger.ac.uk) by going to `Project/Api Access`. This is your credentials for accessing the OpenStack command line interface.

* Copy your OpenStack RC Files to the farm node:

```
scp YOUR_OPENRC_V2.sh YOUR_USER_NAME@farm4-head1:~
scp YOUR_OPENRC_V3.sh YOUR_USER_NAME@farm4-head1:~
```

* Login to the farm node:

```
ssh YOUR_USER_NAME@farm4-head1
```


* Substitute the following lines in the `YOUR_OPENRC_V3.sh` file:

```
echo "Please enter your OpenStack Password for project $OS_PROJECT_NAME as user $OS_USERNAME: "
read -sr OS_PASSWORD_INPUT
export OS_PASSWORD=$OS_PASSWORD_INPUT
```

with the just the following line:

```
export OS_PASSWORD=YOUR_OPENSTACK_PASSWORD
```
(please paste the actual password)

* Substitute `export OS_PROJECT_ID=...` in the `YOUR_OPENRC_V3.sh` file with the `export OS_TENANT_ID=...` which you can find in the `YOUR_OPENRC_V2.sh` file.

* Delete `unset OS_TENANT_ID` from the `YOUR_OPENRC_V3.sh` file.

* Put the sourcing of the `YOUR_OPENRC_V3.sh` into your `.bashrc`.

* If you don't have the `id_rsa` ssh key in your `~/.ssh` folder you will need to generate one and add it to your ssh agent:
```
ssh-keygen -t rsa
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa
```
(follow the instructions)

* Run the following commands which will install all the prerequisites for `kubespray` and enter the `kubspray` directory:

```
git clone https://github.com/cellgeni/kubespray.git
cd kubespray
```

* We have prepared Terraform and Ansible installation for you in a conda environment. To activate the environment please run:
```
source /nfs/cellgeni/.cellgenirc
source activate k8s2.5.0
```

## Terraforming

### Config file and variables

Terraform creates infrastructure from a simple text configuration file. [These instructions](https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#cluster-variables) provide all the necessary information on the terraform configuration file/variables.

Most of the variables in this file can be adjusted for your own needs. However, there are a few of them which represent Sanger OpenStack settings:
```
dns_nameservers=["172.18.255.1"]
floatingip_pool="public"
external_net="bfd77d25-d230-436a-a85a-b28b3dbdb814"
```

These values most probably won't change in the future but you can always obtain them using the OpenStack command line interface.

Flavor type IDs, e.g. `flavor_bastion="8002"`, can be looked up by using the following command:
```
openstack flavor list
```

Kubespray uses [GlusterFS](https://docs.gluster.org/en/latest/) to create a shared volume between the Kubernetes nodes. GlusterFS is a scalable network filesystem suitable for data-intensive tasks such as cloud storage and media streaming. GlusterFS is free and open source software and can utilize common off-the-shelf hardware.

We have pre-configured our development and production clusters, they are located in the `inventory` folders. You can either reuse our settings or create your own folder in the `invetory` folder with your own cluster settings by following [these instructions](https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#inventory-files).


### CIDR subnet

When deploying multiple clusters for each new cluster change `cidr` variable in `../../contrib/terraform/openstack/modules/network/main.tf` to one which wasn't used before, e.g. `10.0.1.0/24` or `10.0.2.0/24`:

```
resource "openstack_networking_subnet_v2" "k8s" {
  name            = "${var.cluster_name}-internal-network"
  network_id      = "${openstack_networking_network_v2.k8s.id}"
  cidr            = "10.0.0.0/24"
  ip_version      = 4
  dns_nameservers = "${var.dns_nameservers}"
}
```

(to check what IP addresses will be used for different subnets you can use a [subnet calculator](https://mxtoolbox.com/subnetcalculator.aspx))

### Run Terraform

The next step is to create the cloud infrastructure for kubernetes using Terraform. Please follow [these instructions](https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#initialization) to do the terraforming step.

Note that Theo created [a pull request](https://github.com/kubernetes-incubator/kubespray/pull/2681) which was not merged to the 2.5.0 release of the kubespray. Therefore we incorporated these changes manually in this repository.

## Ansible

### Network pre-settings

Before running Ansible, make sure to update the `openstack_lbaas_subnet_id` variable in `inventory/CLUSTER/group_vars/all.yml` the with the `subnet_id` parameter created by terraform:
```
terraform show terraform.tfstate | grep ' subnet_id'
```

Also, when you get to the `configuring OpenStack Neutron ports` for __calico networking__ section please follow [Theo's instructions](https://github.com/theobarberbany/Kubernetes_on_Openstack/tree/master/kubespray) on that and run the following one line (thanks to David Jackson!) substituting the `CLUSTER` with your own cluster names defined in the terraform configuration file:
```
neutron port-list -c id -c device_id  | grep -E $(nova list | grep $CLUSTER | awk '{print $2}' | xargs echo | tr ' ' '|') | awk '{print $2}' | xargs -n 1 -I XXX echo neutron port-update XXX --allowed_address_pairs list=true type=dict ip_address=10.233.0.0/18 ip_address=10.233.64.0/18 | bash -eEx
```

### TERRAFORM_STATE_ROOT variable

**Important!** Before running the Ansible playbooks make sure you set the `TERRAFORM_STATE_ROOT` to the path of your cluster inventory folder, e.g. from the root `kubespray` folder run:
```
export TERRAFORM_STATE_ROOT=$(pwd)/inventory/$CLUSTER
```
In this case you can deploy multiple clusters from the same kubespray folder. `TERRAFORM_STATE_ROOT` will tell Ansible only to use hosts of your `$CLUSTER` from the terraform state file of the `inventory/$CLUSTER` folder only. If you don't do that Ansible may start updating all of you clusters.

### Run Ansible

From the root `kubespray` directory run ansible following [these instructions](https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#ansible)

### Glusterfs provision

Now when kubernetes is installed we need to setup glusterfs volumes. From the root `kubespray` directory run:

```
ansible-playbook --become -i inventory/$CLUSTER/hosts contrib/network-storage/glusterfs/glusterfs.yml
```

At this step we found a bug which we created [a pull request](https://github.com/kubernetes-incubator/kubespray/pull/3079) for, but it was not added to the 2.5.0 release of kubespray, therefore we added it manually to this repository.

After running all of the above with no errors you should have you Kubernetes cluster working and ready to be used. Congratulations!

## GlusterFS hostpath provision

In this step we will mount GlusterFS to all of the cluster working nodes. We will use Ansible for that and run it only for the working nodes group of hosts. To find all Ansible hosts:
```
inventory/$CLUSTER/hosts --hostfile
```

To find to which ansible group the host belongs to (search for `kubespray_groups` section):
```
inventory/$CLUSTER/hosts --host $CLUSTER-k8s-master-nf-3
inventory/$CLUSTER/hosts --host $CLUSTER-k8s-node-nf-2
```

The script above provides us with a list of ansible groups:

* kube-master
* kube-node
* gfs-cluster
* bastion

When the groups are known Ansible allows to provision only to hosts corresponding to a specific group.

In our case we would like to mount GlusterFS volume to the `kube-node` group.

### Glusterfs config files

Before mounting glusterfs we need to tell ansible IP addresses of the glusterfs nodes. We do this via [glusterfs-config file](sanger/glusterfs-config). Substitute both `REMOTE-HOST-1` and `REMOTE-HOST-2` in that with the IP addressed of the glusterfs nodes. You can use the `inventory/$CLUSTER/hosts --hostfile` command above to find the IP addresses.

### Run ansible

```
# Create directories using module `file`:
ansible kube-node -b -i inventory/$CLUSTER/hosts -m file -a "path=/mnt/gluster state=directory"
ansible kube-node -b -i inventory/$CLUSTER/hosts -m file -a "path=/etc/glusterfs state=directory"

# Copy gluster-config using module `copy`:
ansible kube-node -b -i inventory/$CLUSTER/hosts -m copy -a "src=sanger/glusterfs-config dest=/etc/glusterfs/"

# Add glusterfs line to `/etc/fstab`:
ansible kube-node -b -i inventory/$CLUSTER/hosts -m lineinfile -a 'dest=/etc/fstab line="/etc/glusterfs/glusterfs-config /mnt/gluster glusterfs rw 0 0"'

# Finally, mount glusterfs:
ansible kube-node -b -i inventory/$CLUSTER/hosts -a "mount -a"

# This is needed for iRods to work
# `-m shell` is used to escape redirection in the script
ansible kube-node -b -i inventory/$CLUSTER/hosts -m shell -a "echo search internal.sanger.ac.uk > /etc/resolvconf/resolv.conf.d/base && resolvconf -u"
```

## kubectl

To access your cluster please look at [these instructions](https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#set-up-kubectl) on how to setup `kubectl`, a command line interface for Kubernetes. We recommend that you set it up on you local computer (not on the `farm4-head1` node). Then you will be able to access the cluster from your computer directly. Here are some important steps for `kubectl` setup on your computer:

* Copy the private ssh key (`cellgeni-su-farm4` in our case) from `farm4-head1` to `~/.ssh` folder on your computer and change its permission to 600:
```
chmod 600 ~/.ssh/cellgeni-su-farm4
```

* Add this to your `~/.ssh/config` file (substitute BASTION_IP and with your own ones):
```
Host 10.0.0.*
       ProxyCommand ssh -W %h:%p bastion
       User ubuntu
       IdentityFile ~/.ssh/cellgeni-su-farm4
       ForwardX11 yes
       ForwardAgent yes
       ForwardX11Trusted yes
Host bastion
       Hostname BASTION_IP
       User ubuntu
       IdentityFile ~/.ssh/cellgeni-su-farm4
       ForwardX11 yes
       ForwardAgent yes
       ForwardX11Trusted yes
Host master
       Hostname MASTER_INTERNAL_IP
       IdentityFile ~/.ssh/cellgeni-su-farm4
       ProxyCommand ssh -W %h:%p bastion
       User ubuntu
```

* If you followed instructions on setting up kubectl above your `~/.kube/config` file should contain something like that (make sure that `server: https://127.0.0.1:16443` is in there):
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /Users/vk6/$CLUSTER/ca.pem
    server: https://127.0.0.1:16443
  name: default-cluster
contexts:
- context:
    cluster: default-cluster
    user: default-admin
  name: default-system
current-context: default-system
kind: Config
preferences: {}
users:
- name: default-admin
  user:
    client-certificate: /Users/vk6/$CLUSTER/admin.pem
    client-key: /Users/vk6/$CLUSTER/admin-key.pem
```

* Create an ssh port forwarding (you will need to rerun it from time to time to keep the connection alive):
```
ssh -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -l ubuntu -Nf -L 16443:MASTER_INTERNAL_IP:6443 BASTION_IP
```
If the above provide an error like:
```
bind: Address already in use
channel_setup_fwd_listener_tcpip: cannot listen to port: 16443
Could not request local forwarding.
```
run this command first:
```
lsof -ti:16443 | xargs kill -9
```

## Services and web sites

For installation instruction on services and web sites used by Cellgeni on this Kubernetes (JupyterHub, Nextflow, etc.), see [here](docs/services.md).
