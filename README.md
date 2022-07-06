# Note
Terraform version use: terraform_0.13.7

# Purpose
Purpose of this repo is to use Terraform to provision infrasture for a simple web applications hosted on AWS.

## Initialize
On first time run, need to do folllowing steps

Step 1: Initialize terraform to download provider login
* cd to git directory folder
* run following command `terraform init`

Step 2: Authenticate to aws cli
* Install AWS CLI 
* From powershell or other OS command line, login with `aws configure`
  Enter AWS Access Key & Secret key
* Region for this project will be on ap-southeast-2 (Sydney)
