terraform {
  required_providers {
    bowtie = {
      source  = "bowtieworks/bowtie"
      version = "0.5.1"
    }
    checkmate = {
      source = "tetratelabs/checkmate"
      version = "1.5.0"
    }
    aws = {
        source = "hashicorp/aws"
    }
  }
}


resource "checkmate_http_health" "baseline_up" {
  # This is the url of the endpoint we want to check
  url = "${var.api_hostname}/-net/api/v0/ok"

  # Will perform an HTTP GET request
  method = "GET"

  # The overall test should not take longer than 15 minutes
  timeout = 1000 * 60 * 15 # ms, seconds, minutes

  # Wait 0.5 seconds between attempts
  interval = 500

  # Expect a status 200 OK
  status_code = 200

  # We want 2 successes in a row
  consecutive_successes = 2
}


module "bowtie-org" {
  depends_on = [checkmate_http_health.baseline_up]
  source    = "./modules/bowtie"
  org_name = var.org_name
  domain = replace(replace(var.api_hostname, "https://", ""), "http://", "")
}
