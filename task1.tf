provider "aws" {
  region     = "ap-south-1"
  profile    = "bhavishya"
}


#Creating_security_group_aws_resource

resource "aws_security_group" "terrascgroup-allow" {
  name        = "terra-scgroup"
  description = "Allow SSH and HTTP"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    description = "HTTP" 
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
 } 
  tags = {
    Name = "terra-scgroup"
  }
}

resource "tls_private_key" "terrakey" {
  algorithm   = "RSA"
}
resource "aws_key_pair" "terrakey-used" {
  key_name   = "terrakey"
  public_key = "${tls_private_key.terrakey.public_key_openssh}"


  depends_on = [
      tls_private_key.terrakey
    ]
}

resource "local_file" "key-file" {
  content  = "${tls_private_key.terrakey.private_key_pem}"
  filename = "terrakey.pem"


  depends_on = [
    tls_private_key.terrakey
  ]
}

resource "aws_instance" "terraform_myinstance" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1a"
  security_groups = [ "${aws_security_group.terrascgroup-allow.name}" ]
  key_name      = aws_key_pair.terrakey-used.key_name
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.terrakey.private_key_pem}"
    host     = aws_instance.terraform_myinstance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "futureos"
  }
}


#creating ebs_volume_aws_resource

resource "aws_ebs_volume" "terraform_data_volume" {
  availability_zone = aws_instance.terraform_myinstance.availability_zone
  size              = 1
  tags = {
	Name = "Terraform_Data"
  }
}


#ebs_volume_attachment_aws_resource

resource "aws_volume_attachment" "terra_attach_vol" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.terraform_data_volume.id}"
  instance_id = "${aws_instance.terraform_myinstance.id}"
  force_detach = true
}

output "os_ip" {
	value = aws_instance.terraform_myinstance.public_ip
}

resource "null_resource" "nullpublicip" {
depends_on = [
       aws_volume_attachment.terra_attach_vol,
   ]

    provisioner "local-exec" {
      command = "chrome ${aws_instance.terraform_myinstance.public_ip}"
    }
}

resource "null_resource" "nullremote" {

depends_on = [
       aws_volume_attachment.terra_attach_vol,
   ]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.terrakey.private_key_pem}"
    host     = aws_instance.terraform_myinstance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/vimallinuxworld13/multicloud.git /var/www/html",
     ]
   }
}
 
#creating_s3_bucket_aws_resource

resource "aws_s3_bucket" "terraforms" {
  bucket = "futurebucket12"
  acl    = "public-read"
  versioning {
    enabled = true
  }

 tags = {
    Name  = "bucket"
    Environment = "Prod"
  }
}

resource "aws_cloudfront_distribution" "terra_cloudfront" {
    origin {
        domain_name = "futurebucket12.s3.amazonaws.com"
        origin_id = "S3-futurebucket12"


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
       
    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-futurebucket12"

        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
 
    restrictions {
        geo_restriction {
           
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true

    }
}