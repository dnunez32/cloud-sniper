# This EC2 is optional if you want to see the dashboard. 
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}


resource "aws_security_group" "access_restricted_ip" {
  name        = "access_restricted_ip"
  description = "Allow access to kibana and ssh from the current ip"
  
  vpc_id = "${var.vpc_id}"

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
    from_port   = 5601
    protocol    = "tcp"
    to_port     = 5601
  }

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
    from_port   = 9200
    protocol    = "tcp"
    to_port     = 9200
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.cloud_sniper_tags
}

resource "aws_instance" "cloudsniper_dashboard" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.medium"
  tags = local.cloud_sniper_tags
  security_groups = ["${aws_security_group.access_restricted_ip.name}"]
  key_name = "${var.ssh_key_name}"

  user_data = <<-EOF
        #! /bin/bash
        sudo apt-get install -y apt-transport-https ca-certificates
        sudo add-apt-repository ppa:openjdk-r/ppa
        sudo apt-get update
        sudo apt install -y openjdk-11-jdk unzip
        wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
        wget -qO - https://d3g5vo6xdbdb9a.cloudfront.net/GPG-KEY-opendistroforelasticsearch | sudo apt-key add -
        echo "deb https://d3g5vo6xdbdb9a.cloudfront.net/apt stable main" | sudo tee -a   /etc/apt/sources.list.d/opendistroforelasticsearch.list
        wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-7.8.0-amd64.deb
        sudo dpkg -i elasticsearch-oss-7.8.0-amd64.deb
        sudo apt-get update
        sudo apt install -y opendistroforelasticsearch
        sudo systemctl start elasticsearch.service
        sudo apt install -y opendistroforelasticsearch-kibana
        echo "server.host: 0.0.0.0" | sudo tee -a /etc/kibana/kibana.yml
        sudo systemctl start kibana.service
        sudo apt install -y logstash
    EOF

}
