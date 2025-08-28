packer {
  required_version = ">= 1.9.0"

  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.2.0"
    }
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">= 1.4.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = ">= 0.12.0"
    }
  }
}
