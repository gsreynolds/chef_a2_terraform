# Instances

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "automate_server" {
  count                       = 1
  ami                         = "${data.aws_ami.ubuntu.id}"
  ebs_optimized               = "${var.instance["ebs_optimized"]}"
  instance_type               = "${var.instance["automate_server_flavor"]}"
  associate_public_ip_address = "${var.instance["automate_server_public"]}"
  subnet_id                   = "${element(aws_subnet.az_subnets.*.id, count.index % length(keys(var.az_subnets)))}"
  vpc_security_group_ids      = ["${aws_security_group.chef_automate.id}", "${aws_security_group.ssh.id}"]
  key_name                    = "${var.instance_keys["key_name"]}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["automate_server"], count.index + 1, var.domain)}"
    )
  )}"

  root_block_device {
    delete_on_termination = "${var.instance["automate_server_term"]}"
    volume_size           = "${var.instance["automate_server_size"]}"
    volume_type           = "${var.instance["automate_server_type"]}"
    iops                  = "${var.instance["automate_server_iops"]}"
  }

  connection {
    host        = "${self.public_ip}"
    user        = "${var.ami_user}"
    private_key = "${file("${var.instance_keys["key_file"]}")}"
  }

  # provisioner "file" {
  #   source      = "automate.license"
  #   destination = "/root/automate.license"
  # }

  provisioner "remote-exec" {
    inline = [
      "sudo hostname ${format("%s%02d.%s", var.instance_hostname["automate_server"], count.index + 1, var.domain)}",
      "sudo hostnamectl set-hostname ${format("%s%02d.%s", var.instance_hostname["automate_server"], count.index + 1, var.domain)}",
      "echo ${format("%s%02d.%s", var.instance_hostname["automate_server"], count.index + 1, var.domain)} | sudo tee /etc/hostname",
      "sudo apt-get install zip curl",
      "wget https://packages.chef.io/files/current/automate/latest/chef-automate_linux_amd64.zip",
      "sudo unzip chef-automate_linux_amd64.zip -d /usr/local/bin",
      "echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.conf",
      "echo vm.dirty_expire_centisecs=20000 | sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -p /etc/sysctl.conf",
      "sudo chef-automate init-config",
      "yes | sudo chef-automate deploy --channel current --upgrade-strategy none --skip-preflight config.toml",

      # "chef-automate license apply $(cat automate.license)",
      # "rm automate.license",
      "sudo chef-automate admin-token | tee data-collector.token",
    ]
  }
}

resource "aws_eip" "automate_server" {
  vpc        = true
  count      = 1
  instance   = "${element(aws_instance.automate_server.*.id, count.index)}"
  depends_on = ["aws_internet_gateway.main"]

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["automate_server"], count.index + 1, var.domain)}"
    )
  )}"
}

resource "aws_instance" "chef_server" {
  count                       = 1
  ami                         = "${data.aws_ami.ubuntu.id}"
  ebs_optimized               = "${var.instance["ebs_optimized"]}"
  instance_type               = "${var.instance["chef_server_flavor"]}"
  associate_public_ip_address = "${var.instance["chef_server_public"]}"
  subnet_id                   = "${element(aws_subnet.az_subnets.*.id, count.index % length(keys(var.az_subnets)))}"
  vpc_security_group_ids      = ["${aws_security_group.chef_automate.id}", "${aws_security_group.ssh.id}"]
  key_name                    = "${var.instance_keys["key_name"]}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["chef_server"], count.index + 1, var.domain)}"
    )
  )}"

  root_block_device {
    delete_on_termination = "${var.instance["chef_server_term"]}"
    volume_size           = "${var.instance["chef_server_size"]}"
    volume_type           = "${var.instance["chef_server_type"]}"
    iops                  = "${var.instance["chef_server_iops"]}"
  }

  connection {
    host        = "${self.public_ip}"
    user        = "${var.ami_user}"
    private_key = "${file("${var.instance_keys["key_file"]}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostname ${format("%s%02d.%s", var.instance_hostname["chef_server"], count.index + 1, var.domain)}",
      "sudo hostnamectl set-hostname ${format("%s%02d.%s", var.instance_hostname["chef_server"], count.index + 1, var.domain)}",
      "echo ${format("%s%02d.%s", var.instance_hostname["chef_server"], count.index + 1, var.domain)} | sudo tee /etc/hostname",
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-server -d /tmp",
      "sudo mkdir /etc/opscode",
      "echo 'topology \"standalone\"' | sudo tee -a /etc/opscode/chef-server.rb",
      "echo 'api_fqdn \"${format("%s%02d.%s", var.instance_hostname["chef_server"], count.index + 1, var.domain)}\"' | sudo tee -a /etc/opscode/chef-server.rb",
      "sudo chef-server-ctl reconfigure",
    ]
  }
}

resource "aws_eip" "chef_server" {
  vpc        = true
  count      = 1
  instance   = "${element(aws_instance.chef_server.*.id, count.index)}"
  depends_on = ["aws_internet_gateway.main"]

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["chef_server"], count.index + 1, var.domain)}"
    )
  )}"
}
