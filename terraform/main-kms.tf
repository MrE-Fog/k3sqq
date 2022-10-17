resource "aws_kms_key" "cloudk3s" {
  for_each                 = toset(["cw", "ec2", "lambda", "rds", "s3", "ssm"])
  description              = "${local.prefix}-${local.suffix}-${each.value}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = "true"
  deletion_window_in_days  = 7
  tags = {
    Name = "${local.prefix}-${local.suffix}-${each.value}"
  }
  policy = data.aws_iam_policy_document.cloudk3s-kms[each.value].json
}