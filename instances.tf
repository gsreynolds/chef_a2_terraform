resource "aws_instance" "automate" {
  provisioner "file" {
    source      = "automate.license"
    destination = "/root/automate.license"
  }

  provisioner "remote-exec" {
    inline = [
      "hostname automate..........",
      "hostnamectl set-hostname automate.......",
      "echo automate.... | tee /etc/hostname",
      "apt-get install zip curl",
      "curl https://packages.chef.io/files/current/automate/latest/chef-automate_linux_amd64.zip",
      "unzip chef-automate_linux_amd64.zip -d /usr/sbin",
      "echo vm.max_map_count=262144 | tee -a /etc/sysctl.conf",
      "echo vm.dirty_expire_centisecs=20000 | tee -a /etc/sysctl.conf",
      "sysctl -p /etc/sysctl.conf",
      "chef-automate init-config",
      "yes | chef-automate deploy --channel current --upgrade-strategy none --skip-preflight config.toml",
      "chef-automate license apply $(cat automate.license)",
      "rm automate.license",
      "chef-automate admin-token > data-collector-token",
    ]
  }
}

resource "aws_instance" "chef" {
  provisioner "remote-exec" {
    inline = [
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-server -d /tmp",
      "sudo chef-server-ctl reconfigure",
    ]
  }
}

# "sudo chef-server-ctl set-secret data_collector token '<API_TOKEN_FROM_STEP_1>'",
# "sudo chef-server-ctl restart nginx",
# "sudo chef-server-ctl restart opscode-erchef",
# data_collector['root_url'] = 'https://automate.example.com/data-collector/v0/'
# # Add for chef client run forwarding
# data_collector['proxy'] = true
# # Add for compliance scanning
# profiles['root_url'] = 'https://automate.example.com'
# # Save and close the file


# sudo chef-server-ctl reconfigure

