# ============================================================================
# modules/email/main.tf
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# SES DOMAIN IDENTITY
# ============================================================================

resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# ============================================================================
# SES EMAIL IDENTITIES (for development/testing)
# ============================================================================

resource "aws_ses_email_identity" "emails" {
  count = length(var.ses_email_list)
  email = var.ses_email_list[count.index]
}

# ============================================================================
# SES CONFIGURATION SET
# ============================================================================

resource "aws_ses_configuration_set" "main" {
  name = "${local.name_prefix}-ses-config"

  delivery_options {
    tls_policy = "Require"
  }
}

# ============================================================================
# SES EVENT DESTINATION (CloudWatch)
# ============================================================================

resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "${local.name_prefix}-ses-events"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["send", "delivery", "bounce", "complaint"]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "MessageTag"
    value_source   = "messageTag"
  }
}

# ============================================================================
# IAM USER FOR SMTP CREDENTIALS
# ============================================================================

resource "aws_iam_user" "ses_smtp" {
  name = "${local.name_prefix}-ses-smtp-user"
  path = "/ses/"

  tags = var.tags
}

resource "aws_iam_user_policy" "ses_smtp" {
  name = "${local.name_prefix}-ses-smtp-policy"
  user = aws_iam_user.ses_smtp.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = var.ses_email_list
          }
        }
      }
    ]
  })
}

resource "aws_iam_access_key" "ses_smtp" {
  user = aws_iam_user.ses_smtp.name
}

# ============================================================================
# CLOUDWATCH LOG GROUP FOR SES
# ============================================================================

resource "aws_cloudwatch_log_group" "ses" {
  name              = "/aws/ses/${local.name_prefix}"
  retention_in_days = 7

  tags = var.tags
}
