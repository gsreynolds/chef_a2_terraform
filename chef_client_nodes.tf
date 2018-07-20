resource "aws_instance" "chef_clients" {
  count      = 3
  depends_on = ["aws_instance.chef_server"]
  ami        = "${data.aws_ami.ubuntu.id}"

  # ebs_optimized               = "${var.instance["ebs_optimized"]}"
  instance_type               = "${var.instance["chef_client_flavor"]}"
  associate_public_ip_address = "${var.instance["chef_client_public"]}"
  subnet_id                   = "${element(aws_subnet.az_subnets.*.id, count.index % length(keys(var.az_subnets)))}"
  vpc_security_group_ids      = ["${aws_security_group.ssh.id}"]
  key_name                    = "${var.instance_keys["key_name"]}"

  iam_instance_profile = "${aws_iam_instance_profile.chef_validator.name}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["chef_client"], count.index + 1, var.domain)}"
    )
  )}"

  root_block_device {
    delete_on_termination = "${var.instance["chef_client_term"]}"
    volume_size           = "${var.instance["chef_client_size"]}"
    volume_type           = "${var.instance["chef_client_type"]}"
    iops                  = "${var.instance["chef_client_iops"]}"
  }

  connection {
    host        = "${self.public_ip}"
    user        = "${var.ami_user}"
    private_key = "${file("${var.instance_keys["key_file"]}")}"
  }

  # https://docs.chef.io/install_bootstrap.html#unattended-installs
  provisioner "remote-exec" {
    inline = [
      "sudo apt update && sudo apt install -y ntp python3",
      "export LC_ALL='en_US.UTF-8' && export LC_CTYPE='en_US.UTF-8' && sudo dpkg-reconfigure  --frontend=noninteractive locales",
      "wget https://bootstrap.pypa.io/get-pip.py && sudo python3 get-pip.py -q",
      "sudo pip -q install awscli --upgrade",
      "sudo hostname ${self.tags.Name}",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "echo ${self.tags.Name} | sudo tee /etc/hostname",
      "sudo mkdir -p /etc/chef && sudo mkdir -p /var/lib/chef && sudo mkdir -p /var/log/chef",
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef -d /tmp",
      "aws ssm get-parameter --name ${var.validator_key_path}chef_validator --with-decryption --output text --query Parameter.Value --region ${var.provider["region"]} | sudo tee /etc/chef/validator.pem > /dev/null",
    ]
  }

  provisioner "file" {
    source      = "first-boot.json"
    destination = "first-boot.json"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'log_location STDOUT' | sudo tee /etc/chef/client.rb",
      "echo 'chef_server_url \"https://${aws_instance.chef_server.tags.Name}/organizations/test\"' | sudo tee -a /etc/chef/client.rb",
      "echo 'validation_client_name \"test-validator\"' | sudo tee -a /etc/chef/client.rb",
      "echo 'validation_key \"/etc/chef/validator.pem\"' | sudo tee -a /etc/chef/client.rb",
      "echo 'node_name  \"${self.tags.Name}\"' | sudo tee -a /etc/chef/client.rb",
      "echo 'ssl_verify_mode :verify_none' | sudo tee -a /etc/chef/client.rb",
      "sudo mv first-boot.json /etc/chef/first-boot.json",
      "sudo chef-client -j /etc/chef/first-boot.json",
    ]
  }
}

resource "aws_route53_record" "chef_clients" {
  count   = 3
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${element(aws_instance.chef_clients.*.tags.Name, count.index)}"
  type    = "A"
  ttl     = "${var.r53_ttl}"
  records = ["${element(aws_instance.chef_clients.*.public_ip, count.index)}"]
}
