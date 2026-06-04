# Random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# # SSH Key Pair
# resource "tls_private_key" "linkhub" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# # AWS Key Pair
# resource "aws_key_pair" "linkhub" {
#   key_name   = "linkhub-key-${random_id.suffix.hex}"
#   public_key = tls_private_key.linkhub.public_key_openssh
# }

# # Save private key locally
# resource "local_file" "private_key" {
#   content         = tls_private_key.linkhub.private_key_pem
#   filename        = "../linkhub-key.pem"
#   file_permission = "0600"
# }

# # Use existing SSH Key Pair from AWS
# resource "aws_key_pair" "linkhub" {
#   key_name   = "linkhub-key"
#   public_key = file("linkhub-key.pub")
# }

# # EC2 Instance
# resource "aws_instance" "linkhub" {
#   ami                    = "ami-0c101f26f147fa7fd"  # Amazon Linux 2 us-east-1
#   instance_type          = "t2.micro"
#   subnet_id              = aws_subnet.public.id
#   vpc_security_group_ids = [aws_security_group.web.id]
#   key_name               = aws_key_pair.linkhub.key_name

# EC2 Instance
resource "aws_instance" "linkhub" {
  ami                    = "ami-0c101f26f147fa7fd"  # Amazon Linux 2 us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "linkhub-key"   # ← Changed to string
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3-pip git
    pip3 install flask flask-cors
    mkdir -p /home/ec2-user/app
    cat > /home/ec2-user/app/app.py << 'APPEOF'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({"message": "LinkHub API is running!", "status": "healthy"})

@app.route('/health')
def health():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
APPEOF
    cd /home/ec2-user/app
    nohup python3 app.py > /dev/null 2>&1 &
    echo "LinkHub deployed!" > /home/ec2-user/status.txt
  EOF

  tags = {
    Name = "linkhub-server"
  }
}

# Elastic IP
resource "aws_eip" "linkhub" {
  instance = aws_instance.linkhub.id
  domain   = "vpc"

  tags = {
    Name = "linkhub-eip"
  }
}