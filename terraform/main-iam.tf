## autoscaling
resource "aws_iam_service_linked_role" "k3s" {
  aws_service_name = "autoscaling.amazonaws.com"
  custom_suffix    = "${local.prefix}-${local.suffix}"
}

resource "aws_iam_policy" "k3s-ec2-passrole" {
  name   = "${local.prefix}-${local.suffix}-ec2-passrole"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-ec2-passrole.json
}

resource "aws_iam_user_policy_attachment" "k3s-ec2-passrole" {
  user       = element(split("/", data.aws_caller_identity.k3s.arn), 1)
  policy_arn = aws_iam_policy.k3s-ec2-passrole.arn
}

## codebuild
resource "aws_iam_role" "k3s-codebuild" {
  name               = "${local.prefix}-${local.suffix}-codebuild"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.k3s-codebuild-trust.json
}

resource "aws_iam_policy" "k3s-codebuild" {
  name   = "${local.prefix}-${local.suffix}-codebuild"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-codebuild.json
}

resource "aws_iam_role_policy_attachment" "k3s-codebuild" {
  role       = aws_iam_role.k3s-codebuild.name
  policy_arn = aws_iam_policy.k3s-codebuild.arn
}

## codepipeline
resource "aws_iam_role" "k3s-codepipeline" {
  name               = "${local.prefix}-${local.suffix}-codepipeline"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.k3s-codepipeline-trust.json
}

resource "aws_iam_policy" "k3s-codepipeline" {
  name   = "${local.prefix}-${local.suffix}-codepipeline"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-codepipeline.json
}

resource "aws_iam_role_policy_attachment" "k3s-codepipeline" {
  role       = aws_iam_role.k3s-codepipeline.name
  policy_arn = aws_iam_policy.k3s-codepipeline.arn
}

## ec2
resource "aws_iam_role" "k3s-ec2" {
  name               = "${local.prefix}-${local.suffix}-ec2"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.k3s-ec2-trust.json
}

resource "aws_iam_policy" "k3s-ec2" {
  name   = "${local.prefix}-${local.suffix}-ec2"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-ec2.json
}

resource "aws_iam_role_policy_attachment" "k3s-ec2" {
  role       = aws_iam_role.k3s-ec2.name
  policy_arn = aws_iam_policy.k3s-ec2.arn
}

resource "aws_iam_role_policy_attachment" "k3s-ec2-managed" {
  role       = aws_iam_role.k3s-ec2.name
  policy_arn = data.aws_iam_policy.k3s-ec2-managed.arn
}

resource "aws_iam_instance_profile" "k3s-ec2" {
  name = "${local.prefix}-${local.suffix}-ec2"
  role = aws_iam_role.k3s-ec2.name
}

## lambda
resource "aws_iam_role" "k3s-lambda-getk3s" {
  name               = "${local.prefix}-${local.suffix}-lambda-getk3s"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.k3s-lambda-getk3s-trust.json
}

resource "aws_iam_policy" "k3s-lambda-getk3s" {
  name   = "${local.prefix}-${local.suffix}-lambda-getk3s"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-lambda-getk3s.json
}

resource "aws_iam_role_policy_attachment" "k3s-lambda-getk3s" {
  role       = aws_iam_role.k3s-lambda-getk3s.name
  policy_arn = aws_iam_policy.k3s-lambda-getk3s.arn
}

resource "aws_iam_role_policy_attachment" "k3s-lambda-getk3s-managed-1" {
  role       = aws_iam_role.k3s-lambda-getk3s.name
  policy_arn = data.aws_iam_policy.k3s-lambda-getk3s-managed-1.arn
}

resource "aws_iam_role_policy_attachment" "k3s-lambda-getk3s-managed-2" {
  role       = aws_iam_role.k3s-lambda-getk3s.name
  policy_arn = data.aws_iam_policy.k3s-lambda-getk3s-managed-2.arn
}

resource "aws_iam_role" "k3s-lambda-oidcprovider" {
  name               = "${local.prefix}-${local.suffix}-lambda-oidcprovider"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.k3s-lambda-oidcprovider-trust.json
}

resource "aws_iam_policy" "k3s-lambda-oidcprovider" {
  name   = "${local.prefix}-${local.suffix}-lambda-oidcprovider"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-lambda-oidcprovider.json
}

resource "aws_iam_role_policy_attachment" "k3s-lambda-oidcprovider" {
  role       = aws_iam_role.k3s-lambda-oidcprovider.name
  policy_arn = aws_iam_policy.k3s-lambda-oidcprovider.arn
}

resource "aws_iam_role_policy_attachment" "k3s-lambda-oidcprovider-managed-1" {
  role       = aws_iam_role.k3s-lambda-oidcprovider.name
  policy_arn = data.aws_iam_policy.k3s-lambda-oidcprovider-managed-1.arn
}

resource "aws_iam_role_policy_attachment" "k3s-lambda-oidcprovider-managed-2" {
  role       = aws_iam_role.k3s-lambda-oidcprovider.name
  policy_arn = data.aws_iam_policy.k3s-lambda-oidcprovider-managed-2.arn
}

## irsa
resource "aws_iam_role" "k3s-irsa" {
  name               = "${local.prefix}-${local.suffix}-irsa"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.k3s-irsa-trust.json
  depends_on         = [data.aws_lambda_invocation.k3s-oidcprovider]
}

resource "aws_iam_policy" "k3s-irsa" {
  name   = "${local.prefix}-${local.suffix}-irsa"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-irsa.json
}

resource "aws_iam_role_policy_attachment" "k3s-irsa" {
  role       = aws_iam_role.k3s-irsa.name
  policy_arn = aws_iam_policy.k3s-irsa.arn
}

## aws-cloud-controller-manager
resource "aws_iam_role" "k3s-aws-cloud-controller-manager" {
  name               = "${local.prefix}-${local.suffix}-aws-cloud-controller-manager"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.k3s-aws-cloud-controller-manager-trust.json
  depends_on         = [data.aws_lambda_invocation.k3s-oidcprovider]
}

resource "aws_iam_policy" "k3s-aws-cloud-controller-manager" {
  name   = "${local.prefix}-${local.suffix}-aws-cloud-controller-manager"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-aws-cloud-controller-manager.json
}

resource "aws_iam_role_policy_attachment" "k3s-aws-cloud-controller-manager" {
  role       = aws_iam_role.k3s-aws-cloud-controller-manager.name
  policy_arn = aws_iam_policy.k3s-aws-cloud-controller-manager.arn
}

## aws-vpc-cni
resource "aws_iam_role" "k3s-aws-vpc-cni" {
  name               = "${local.prefix}-${local.suffix}-aws-vpc-cni"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.k3s-aws-vpc-cni-trust.json
  depends_on         = [data.aws_lambda_invocation.k3s-oidcprovider]
}

resource "aws_iam_policy" "k3s-aws-vpc-cni" {
  name   = "${local.prefix}-${local.suffix}-aws-vpc-cni"
  path   = "/"
  policy = data.aws_iam_policy_document.k3s-aws-vpc-cni.json
}

resource "aws_iam_role_policy_attachment" "k3s-aws-vpc-cni" {
  role       = aws_iam_role.k3s-aws-vpc-cni.name
  policy_arn = aws_iam_policy.k3s-aws-vpc-cni.arn
}
# ## awslbcontroller
# resource "aws_iam_role" "k3s-awslbcontroller" {
#   name               = "${local.prefix}-${local.suffix}-awslbcontroller"
#   path               = "/"
#   assume_role_policy = data.aws_iam_policy_document.k3s-awslbcontroller-trust.json
#   depends_on         = [data.aws_lambda_invocation.k3s-oidcprovider]
# }

# resource "aws_iam_policy" "k3s-awslbcontroller" {
#   name   = "${local.prefix}-${local.suffix}-awslbcontroller"
#   path   = "/"
#   policy = data.aws_iam_policy_document.k3s-awslbcontroller.json
# }

# resource "aws_iam_role_policy_attachment" "k3s-awslbcontroller" {
#   role       = aws_iam_role.k3s-awslbcontroller.name
#   policy_arn = aws_iam_policy.k3s-awslbcontroller.arn
# }