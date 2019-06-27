Vagrant.require_version ">= 1.7.0"

Vagrant.configure(2) do |config|

  config.vm.box = "ubuntu/bionic64"

  config.vm.hostname = "vagrant-ansible.tag1consulting.com"
  config.vm.provider "virtualbox" do |v|
   v.customize ["modifyvm", :id, "--audio", "none"]
   v.memory = 2048
   v.cpus = 2
  end

  # Disable the new default behavior introduced in Vagrant 1.7, to
  # ensure that all Vagrant machines will use the same SSH key pair.
  # See https://github.com/mitchellh/vagrant/issues/5005
  config.ssh.insert_key = false

  config.vm.define "vagrant-ansible.tag1consulting.com"

  config.vm.network "forwarded_port", guest: 80, host:8000
  config.vm.network "forwarded_port", guest: 443, host:8443

  config.vm.provision "ansible" do |ansible|
    ansible.compatibility_mode = "2.0"
    ansible.playbook = "site.yaml"
    ansible.limit = "all"
    ansible.extra_vars = {
      testing: true 
    }
    if ENV['TAGS'] 
      ansible.tags = ENV['TAGS'].split(',')
    end
    ansible.groups = {
      "webservers" => ["vagrant-ansible.tag1consulting.com"]
    }
  end
end
