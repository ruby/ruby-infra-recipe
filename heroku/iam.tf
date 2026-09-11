# The access key is issued with `aws iam create-access-key` and set on the app
# by hand, because Terraform would keep the secret in plain text in the state.
resource "aws_iam_user" "blade_mcp" {
  name = "blade-mcp"
}

resource "aws_iam_user_policy" "blade_mcp" {
  name = "blade-data-vault-read"
  user = aws_iam_user.blade_mcp.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::blade-data-vault"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::blade-data-vault/*"]
      },
    ]
  })
}
