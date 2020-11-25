resource "aws_cloudwatch_log_group" "main" {
  name = "/aws/lambda/${module.label.id}"

  tags = module.label.tags
}


resource "aws_iam_role" "lambda" {
  name = module.label.id

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_logging" {
  name        = module.label.id
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_permission" "main" {
  statement_id  = "AllowExecution"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.main.arn
}

resource "null_resource" "lambda" {
  provisioner "local-exec" {
    command = "(cd ${path.module}/trigger && pip install -r requirements.txt -t .)"
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source_dir = "${path.module}/trigger"

  depends_on = [ null_resource.lambda ]
}

resource "aws_lambda_function" "main" {
  filename      = data.archive_file.lambda.output_path
  function_name = module.label.id
  role          = aws_iam_role.lambda.arn
  handler       = "main.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
      ENDPOINT = var.trigger_endpoint
    }
  }

  tags = module.label.tags
}