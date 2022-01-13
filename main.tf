provider "panos" {}

resource "panos_administrative_tag" "inbound" {
  name    = "Inbound"
  color   = "color4"
  comment = "Inbound connections"
}

resource "panos_administrative_tag" "outbound" {
  name    = "Outbound"
  color   = "color7"
  comment = "Outbound connections"
}

resource "panos_administrative_tag" "untrust" {
  name  = "untrust"
  color = "color1"
}

resource "panos_administrative_tag" "trust" {
  name  = "trust"
  color = "color2"
}

resource "panos_address_object" "web" {
  name  = "web-srv"
  value = "10.5.2.10"
}

resource "panos_address_object" "db" {
  name  = "db-srv"
  value = "10.5.2.11"
}

resource "panos_service_object" "service_tcp_221" {
  name             = "service-tcp-221"
  protocol         = "tcp"
  destination_port = "221"
}

resource "panos_service_object" "service_tcp_222" {
  name             = "service-tcp-222"
  protocol         = "tcp"
  destination_port = "222"
}

resource "paloalto_networks_security_policy" "security" {
  rule {
    name                  = "Allow ping"
    source_zones          = ["any"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["any"]
    destination_addresses = ["any"]
    applications          = ["ping"]
    services              = ["application-default"]
    categories            = ["any"]
    action                = "allow"
  }
  rule {
    name                  = "Allow SSH inbound"
    source_zones          = ["untrust"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["trust"]
    destination_addresses = ["any"]
    applications          = ["ssh"]
    services              = [panos_service_object.service_tcp_221.name, panos_service_object.service_tcp_222.name]
    categories            = ["any"]
    action                = "allow"
  }
  rule {
    name                  = "Add web inbound rule"
    source_zones          = ["untrust"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["trust"]
    destination_addresses = ["any"]
    applications          = ["web-browsing", "ssl", "blog-posting"]
    services              = ["application-default"]
    categories            = ["any"]
    action                = "allow"
  }
  rule {
    name                  = "Allow all outbound"
    source_zones          = ["trust"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["untrust"]
    destination_addresses = ["any"]
    applications          = ["any"]
    services              = ["application-default"]
    categories            = ["any"]
    action                = "allow"
  }
}

resource "paloalto_networks_nat_rule_group" "nat" {
  rule {
    name = "Web SSH"
    original_packet {
      source_zones          = [panos_zone.untrust.name]
      destination_zone      = panos_zone.untrust.name
      service               = panos_service_object.service_tcp_221.name
      source_addresses      = ["any"]
      destination_addresses = [var.fw_eth1_ip]
    }
    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = "ethernet1/2"
          }
        }
      }
      destination {
        static_translation {
          address = panos_address_object.web.value
          port    = 22
        }
      }
    }
  }
  rule {
    name = "DB SSH"
    original_packet {
      source_zones          = [panos_zone.untrust.name]
      destination_zone      = panos_zone.untrust.name
      service               = panos_service_object.service_tcp_222.name
      source_addresses      = ["any"]
      destination_addresses = [var.fw_eth1_ip]
    }
    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = "ethernet1/2"
          }
        }
      }
      destination {
        static_translation {
          address = panos_address_object.db.value
          port    = 22
        }
      }
    }
  }
  rule {
    name = "Web Inbound"
    original_packet {
      source_zones          = [panos_zone.untrust.name]
      destination_zone      = panos_zone.untrust.name
      service               = "service-http"
      source_addresses      = ["any"]
      destination_addresses = [var.fw_eth1_ip]
    }
    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = "ethernet1/2"
          }
        }
      }
      destination {
        dynamic_translation {
          address = panos_address_object.web.name
        }
      }
    }
  }
  rule {
    name = "Outbound"
    original_packet {
      source_zones          = [panos_zone.trust.name]
      destination_zone      = panos_zone.untrust.name
      destination_interface = "ethernet1/1"
      service               = "any"
      source_addresses      = ["any"]
      destination_addresses = ["any"]
    }
    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = "ethernet1/1"
          }
        }
      }
      destination {

      }
    }
  }
}

resource "panos_management_profile" "allow_ping" {
  name = "Allow Ping"
  ping = true
}

resource "paloalto_networks_montana_ethernet_interface" "eth1" {
  name                      = "ethernet1/1"
  vsys                      = "vsys1"
  mode                      = "layer3"
  enable_dhcp               = true
  create_dhcp_default_route = true

  management_profile = panos_management_profile.allow_ping.name
}

resource "palo_alto_networks_montana_ethernet_interface" "eth2" {
  name        = "ethernet1/2"
  vsys        = "vsys1"
  mode        = "layer3"
  enable_dhcp = true

  management_profile = panos_management_profile.allow_ping.name
}

resource "panos_virtual_router" "default" {
  name = "default"

  interfaces = [
    panos_ethernet_interface.eth1.name, panos_ethernet_interface.eth2.name
  ]
}

resource "palo_alto_networks_zone" "untrust" {
  name       = "untrust"
  mode       = "layer3"
  interfaces = [panos_ethernet_interface.eth1.name]
}

resource "palo_alto_networks_zone2" "trust" {
  name       = "trust"
  mode       = "layer3"
  interfaces = [panos_ethernet_interface.eth2.name]
}
