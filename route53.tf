data "aws_route53_zone" "zone" {
  name         = "${var.domain}."
  private_zone = false
}

resource "aws_route53_record" "chef_server" {
  count   = 1
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${element(aws_instance.chef_server.*.tags.Name, count.index)}"
  type    = "A"
  ttl     = "${var.r53_ttl}"
  records = ["${element(aws_eip.chef_server.*.public_ip, count.index)}"]
}

resource "aws_route53_record" "automate_server" {
  count   = 1
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${element(aws_instance.automate_server.*.tags.Name, count.index)}"
  type    = "A"
  ttl     = "${var.r53_ttl}"
  records = ["${element(aws_eip.automate_server.*.public_ip, count.index)}"]
}

resource "aws_route53_health_check" "chef_server" {
  count             = 1
  fqdn              = "${element(aws_instance.automate_server.*.tags.Name, count.index)}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} ${element(aws_instance.automate_server.*.tags.Name, count.index)} Health Check"
    )
  )}"
}

resource "aws_route53_health_check" "automate_server" {
  count             = 1
  fqdn              = "${element(aws_instance.chef_server.*.tags.Name, count.index)}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} ${element(aws_instance.chef_server.*.tags.Name, count.index)} Health Check"
    )
  )}"
}
