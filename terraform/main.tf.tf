resource "aws_lambda_function" "zwell_api_lambda" {
  function_name = "zwell-data-api-lambda"
  role = aws_iam_role.zwell_data_api_role.arn
  image_uri = "${aws_ecr_repository.lambda_image_repo.repository_url}:${var.image_tag}"
  package_type = "Image"
  architectures = ["arm64"]
  memory_size = 521
  timeout = 10 // 10 seconds

  image_config {
    command = [ "lambda.handler" ]
  }
}

// lambda role to assume role
data "aws_iam_policy_document" "lambda_assume_document" {
  statement {
    sid = "assumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "zwell_data_api_role" {
  name               = "zwell_data_api_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_document.json
}

// api-gateway invoke permission
resource "aws_lambda_permission" "zwell-api-gw-permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zwell_api_lambda.function_name

  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.zwell-api-gateway.execution_arn}/*/*"
}


// dynamodb permission
data "aws_iam_policy_document" "zwell_data_api_dynamo_document" {
  statement {
    sid = "dynamoAppliancesREAD"
    effect = "Allow"

    actions = [
        "dynamodb:BatchGetItem",
				"dynamodb:GetItem",
				"dynamodb:Query",
				"dynamodb:Scan"
    ]

    # dynamoTables to allows permissions to
    resources = [
      aws_dynamodb_table.zwell_appliance_table.arn,
      aws_dynamodb_table.zwell_hvac_table.arn,
      aws_dynamodb_table.zwell_home_decade_table.arn,
      aws_dynamodb_table.zwell_home_type_table.arn,
      aws_dynamodb_table.zwell_state_table.arn,
      aws_dynamodb_table.zwell_zipcode_table.arn,
      "${aws_dynamodb_table.zwell_zipcode_table.arn}/index/*",
      aws_dynamodb_table.zwell_biomass_table.arn
    ]
  }
}

resource "aws_iam_policy" "zwell_data_api_dynamo_policy" {
  name = "zwell_data_api_dynamo"
  policy = data.aws_iam_policy_document.zwell_data_api_dynamo_document.json
}

resource "aws_iam_role_policy_attachment" "zwell_data_api_attachment" {
  role = aws_iam_role.zwell_data_api_role.name
  policy_arn = aws_iam_policy.zwell_data_api_dynamo_policy.arn
}

// loggoing 
resource "aws_iam_policy" "function_logging_policy" {
  name   = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  role       = aws_iam_role.zwell_data_api_role.id
  policy_arn = aws_iam_policy.function_logging_policy.arn
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/zwell-data-api-lambda"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}