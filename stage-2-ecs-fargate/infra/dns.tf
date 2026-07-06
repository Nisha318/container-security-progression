# -----------------------------------------------------------------------------
# Route 53 Hosted Zone
# Looks up the hosted zone created when the domain was purchased through Route 53.
# -----------------------------------------------------------------------------

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# -----------------------------------------------------------------------------
# ACM Certificate
# DNS validation is used rather than email validation because Route 53 is
# the DNS provider - OpenTofu can create the validation record automatically
# and aws_acm_certificate_validation can wait for confirmation without any
# manual steps.
#
# create_before_destroy ensures a new cert is valid before the old one is
# destroyed during cert renewal or replacement. Without this, a destroy-then-
# create cycle would leave the ALB with no valid cert during the gap.
#
# subject_alternative_names covers www.containersec.click in addition to
# the apex domain so both work with the same certificate.
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "app" {
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["www.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cert"
  }
}

# -----------------------------------------------------------------------------
# DNS Validation Records
# For each domain in the certificate (apex + www), ACM provides a CNAME
# record value to prove domain ownership. This for_each creates those CNAME
# records in Route 53 automatically.
#
# allow_overwrite = true handles the case where validation records already
# exist from a previous certificate request for the same domain.
# -----------------------------------------------------------------------------

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# -----------------------------------------------------------------------------
# Certificate Validation
# This resource holds tofu apply open until ACM confirms the certificate
# is validated and issued. DNS propagation usually takes 2-3 minutes.
# Cancelling apply while this waits will leave the certificate in a pending
# state requiring manual cleanup in ACM.
# -----------------------------------------------------------------------------

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# -----------------------------------------------------------------------------
# Route 53 Alias Record
# Points the apex domain (containersec.click) at the ALB. An alias record
# is used rather than a CNAME because:
#   - AWS does not charge for alias record DNS queries
#   - Alias records support the apex domain (CNAMEs cannot be used at apex)
#   - evaluate_target_health = true fails over DNS if the ALB is unhealthy
# -----------------------------------------------------------------------------

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# www redirect record
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
