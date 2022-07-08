#!/bin/bash
# Install Apache Web Server and PHP
yum install -y httpd mysql
amazon-linux-extras install -y php7.2
# Download challenge files
wget https://us-west-2-tcprod.s3.amazonaws.com/courses/ILT-TF-100-ARCHIT/v6.5.2/lab-2-webapp/scripts/inventory-app.zip
unzip inventory-app.zip -d /var/www/html/
# Download and install the AWS SDK for PHP
wget https://github.com/aws/aws-sdk-php/releases/download/3.62.3/aws.zip
unzip aws -d /var/www/html
# Turn on web server
chkconfig httpd on
service httpd start

echo "**********************"
echo "Installing SSM Agent"
echo "**********************"
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent
 
echo "**********************"
echo "Installing AWS CLI"
echo "**********************"
yum install python3-pip.noarch -y
echo "export PATH=/root/.local/bin:$PATH" >> /root/.bash_profile
source /root/.bash_profile
pip3 install awscli --upgrade --user
aws configure set s3.signature_version s3v4