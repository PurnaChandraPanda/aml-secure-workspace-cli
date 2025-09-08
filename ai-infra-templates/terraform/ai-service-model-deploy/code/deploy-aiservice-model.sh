#!/bin/bash

set -e

terraform init

terraform apply

# To destroy the resources, uncomment the following line
terraform destroy