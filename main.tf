# ip-cidr을 찾을 AWS region code를 입력합니다.
variable "region" {
  description = "AWS region code"
}

/*
GET EC2 type resources Public IP Range list

curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | \
jq -r '.prefixes[] | select(.region=="ap-northeast-1" and .service=="EC2") | .ip_prefix'
*/

provider "http" {}


# AWS Region병 IP-range를 받기 위한 API call을 보냅니다.
data "http" "aws_ip_ranges" {
  url = "https://ip-ranges.amazonaws.com/ip-ranges.json"
}

locals {
  # EC2 서비스에 귀속되고 변수에 입력한 리전에 귀속된 모든 ip를 불러옵니다.
  # aws ip_range에 대한 결과값을 "ec2_cidrs_raw" 변수에 저장
  ec2_cidrs_raw = [
    for prefix in jsondecode(data.http.aws_ip_ranges.response_body).prefixes :
    prefix.ip_prefix
    if prefix.region == var.region && prefix.service == "EC2"
  ]

  # for 문을 이용해서 ip대역이 24비트를 넘는 cidr는 쪼개서 24비트로 나눠서 값을 정렬합니다.
  ec2_cidrs = flatten([
    for cidr in local.ec2_cidrs_raw :
    # ec2_cidr_raw 로부터 24 비트보다 큰 대역들을 불러와서 24대역으로 분리시켜줍니다.
    # 24 비트보다 낮은 대역들은 따로 출력합니다.
    length(split("/", cidr)[1]) < 24 ? [
      # 24비트 보다 큰 대역들을 24비트 대역으로 나눕니다. ex) 10.0.0.0/16 -> 10.0.1.0/24, 10.0.2.0/24, ...
      for i in range(0, min(256, pow(2, 24 - tonumber(split("/", cidr)[1])))) :
      cidrsubnet(cidr, 24 - tonumber(split("/", cidr)[1]), i)
    ] : [cidr]
  ])
}

# 정렬한 IP-range를 출력합니다.
output "ec2_cidrs" {
  value = local.ec2_cidrs
}
