resource "aws_cloudwatch_event_target" "main" {
  target_id = module.label.id
  rule      = aws_cloudwatch_event_rule.main.name
  arn       = aws_lambda_function.main.arn
}

resource "aws_cloudwatch_event_rule" "main" {
  name        = module.label.id
  description = "Capture successful ECR push events"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.ecr"
  ],
  "detail-type": [
    "ECR Image Action"
  ],
  "detail": {
    "action-type": [
      "PUSH"
    ],
    "result": [
      "SUCCESS"
    ],
    "repository-name": ${jsonencode(var.repositories)}
  }
}
PATTERN
}