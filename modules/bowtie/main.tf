terraform {
  required_providers {
    bowtie = {
      source  = "bowtieworks/bowtie"
      # version = "0.3"
    }
  }
}

resource "bowtie_site" "region" {
  for_each = var.sites
  name     = "AWS ${each.key}"
}

resource "bowtie_site_range" "region_range" {
  for_each = { for site_region in flatten([
    for region, site in var.sites : [
      for visibility, subnet in site.subnets : {
        cidr_block = subnet
        region     = region
        site_id    = site.site_id
        visibility = visibility
      }
    ]]) : "${site_region.region}.${site_region.visibility}" => site_region
  }

  site_id     = bowtie_site.region[each.value["region"]].id
  name        = "AWS ${each.value["region"]} ${each.value["visibility"]}"
  description = "AWS ${each.value["region"]} ${each.value["visibility"]} range"
  ipv4_range  = each.value["cidr_block"]

  depends_on = [bowtie_site.region]
}

resource "bowtie_site_range" "region_range_cross" {
  for_each = { for site_region in flatten([
    for region, site in var.sites : [
      for other_region in setsubtract(keys(var.sites), [region]) : [
        for visibility, subnet in site.subnets : {
          cidr_block   = subnet
          region       = region
          other_region = other_region
          site_id      = site.site_id
          visibility   = visibility
        }
      ]
    ]]) : "${site_region.region}.${site_region.visibility}" => site_region
  }

  site_id     = bowtie_site.region[each.value["region"]].id
  name        = "AWS ${each.value["region"]} ${each.value["visibility"]} cross-region to ${each.value["other_region"]}"
  description = "AWS ${each.value["region"]} ${each.value["visibility"]} range cross-region to ${each.value["other_region"]}"
  ipv4_range  = each.value["cidr_block"]

  depends_on = [bowtie_site.region]
}

resource "bowtie_resource" "all" {
  name     = "All Access"
  protocol = "all"
  location = {
    cidr = "0.0.0.0/0"
  }
  ports = {
    range = [
      0, 65535
    ]
  }
}

resource "bowtie_dns_block_list" "example" {
  name     = "Threat Intelligence Feed"
  upstream = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/tif.txt"
  override_to_allow = [
    "permitted.example.com"
  ]
}

