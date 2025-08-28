// AWS Windows Server 2022 AMI via amazon-ebs

source "amazon-ebs" "windows2022" {
  region         = var.aws_region
  instance_type  = var.instance_type
  associate_public_ip_address = true
  ssh_interface               = "public_ip"

  # Use no communicator; provisioning is executed via AWS Systems Manager (SSM) using shell-local.
  communicator   = "none"

  # Attach an instance profile that allows SSM (AmazonSSMManagedInstanceCore policy)
  iam_instance_profile = var.ssm_iam_instance_profile

  ami_name        = "${var.image_name_prefix}-windows2022-{{timestamp}}"
  ami_description = "${var.project_name} Windows Server 2022 Base"

  # Use Windows Server 2022 English Full Base as the parent AMI
  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    # Microsoft Windows base AMIs are published by this AWS account ID
    # Verify in your region if builds fail
    owners      = ["801119661308"]
    most_recent = true
  }

  # Ensure WinRM is enabled for the build (HTTP/5985, unencrypted/Basic only during build)
  user_data = <<-EOF
    <powershell>
      try {
        $log = 'C:\\ProgramData\\Amazon\\EC2Launch\\log\\user-data-transcript.log'
        Start-Transcript -Path $log -Append | Out-Null
        Set-ExecutionPolicy Bypass -Scope LocalMachine -Force

        # Set a known Administrator password for the duration of the build
        $p = ConvertTo-SecureString "${var.winrm_password}" -AsPlainText -Force
        try { net user Administrator "${var.winrm_password}" } catch {}
        try { Set-LocalUser -Name Administrator -Password $p } catch {}

        # Configure WinRM HTTP (5985) and HTTPS (5986). Enable both listeners; use SkipNetworkProfileCheck.
        Enable-PSRemoting -Force -SkipNetworkProfileCheck
        winrm quickconfig -q
        winrm set winrm/config/winrs @{MaxMemoryPerShellMB="1024"}
        winrm set winrm/config @{MaxTimeoutms="1800000"}
        winrm set winrm/config/service @{AllowUnencrypted="true"}
        winrm set winrm/config/service/auth @{Basic="true"}
        try { winrm create winrm/config/Listener?Address=*+Transport=HTTP } catch {}

        # HTTPS (5986) with a self-signed certificate
        $cert = New-SelfSignedCertificate -DnsName "packer.winrm" -CertStoreLocation Cert:\\LocalMachine\\My
        $thumb = $cert.Thumbprint
        try { winrm delete winrm/config/Listener?Address=*+Transport=HTTPS } catch {}
        winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname="packer.winrm"; CertificateThumbprint="$thumb"}

        # Ensure firewall allows WinRM (enable built-in groups and add explicit rules for all profiles)
        try { netsh advfirewall firewall set rule group="Windows Remote Management" new enable=yes } catch {}
        try { Enable-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -ErrorAction SilentlyContinue } catch {}
        try { Enable-NetFirewallRule -Name 'WINRM-HTTPS-In-TCP' -ErrorAction SilentlyContinue } catch {}
        if (-not (Get-NetFirewallRule -DisplayName 'Packer WinRM 5985' -ErrorAction SilentlyContinue)) {
          New-NetFirewallRule -DisplayName 'Packer WinRM 5985' -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -Profile Any | Out-Null
        }
        if (-not (Get-NetFirewallRule -DisplayName 'Packer WinRM 5986' -ErrorAction SilentlyContinue)) {
          New-NetFirewallRule -DisplayName 'Packer WinRM 5986' -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow -Profile Any | Out-Null
        }

        sc.exe config winrm start= auto | Out-Null
        Restart-Service WinRM

        Start-Sleep -Seconds 10
        try { Test-NetConnection -ComputerName localhost -Port 5985 | Out-String | Add-Content -Path $log } catch {}
        try { Test-NetConnection -ComputerName localhost -Port 5986 | Out-String | Add-Content -Path $log } catch {}

      } catch {
        try { "UserDataError: $($_.Exception.Message)" | Add-Content -Path $log } catch {}
      } finally {
        try { Stop-Transcript | Out-Null } catch {}
      }
    </powershell>
  EOF

  # Root volume settings
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = var.ebs_type
    volume_size           = var.disk_size
    delete_on_termination = true
    encrypted             = var.ami_encrypted
  }

  # Tag the AMI and the build instance
  tags = merge({
    Name        = "${var.image_name_prefix}-windows2022",
    Project     = var.project_name,
    Environment = var.environment,
    ManagedBy   = "packer",
    OS          = "windows",
    Release     = "2022",
  }, var.build_tags)

  # Tag the running instance with a unique token so shell-local can discover the instance-id for SSM
  run_tags = merge({
    Project     = var.project_name,
    Environment = var.environment,
    ManagedBy   = "packer",
    BuildToken  = "{{timestamp}}",
  }, var.build_tags)
}

build {
  name    = "aws-windows-2022"
  sources = [
    "source.amazon-ebs.windows2022",
  ]

  # Orchestrate provisioning via AWS SSM using the local AWS CLI
  # 1) Wait for the builder instance to register in SSM
  provisioner "shell-local" {
    environment_vars = [
      "AWS_REGION=${var.aws_region}",
      "BUILD_TOKEN={{timestamp}}",
    ]
    inline = [
      "set -euo pipefail",
      "INSTANCE_ID=$(aws ec2 describe-instances --region $AWS_REGION --filters Name=tag:BuildToken,Values=$BUILD_TOKEN Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[].InstanceId' --output text | head -n1)",
      "echo Instance: $INSTANCE_ID",
      "echo 'Waiting for SSM agent to be Online...'",
      "for i in $(seq 1 120); do STATUS=$(aws ssm describe-instance-information --region $AWS_REGION --filters Key=InstanceIds,Values=$INSTANCE_ID --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true); if [ \"$STATUS\" = Online ]; then echo SSM Online; break; fi; sleep 10; done",
      "[ \"$STATUS\" = Online ] || { echo 'SSM never became Online'; exit 1; }",
      "echo 'Trigger Windows Updates via SSM (AWS-RunPatchBaseline)...'",
      "PARAMS='{\"Operation\":[\"Install\"],\"RebootOption\":[\"RebootIfNeeded\"]}'",
      "CMD_ID=$(aws ssm send-command --region $AWS_REGION --instance-ids $INSTANCE_ID --document-name AWS-RunPatchBaseline --parameters \"$PARAMS\" --query Command.CommandId --output text)",
      "echo CommandId: $CMD_ID",
      "for i in $(seq 1 180); do ST=$(aws ssm list-command-invocations --region $AWS_REGION --command-id $CMD_ID --details --query 'CommandInvocations[0].Status' --output text 2>/dev/null || true); case \"$ST\" in Success) echo 'Updates Success'; break;; InProgress|Pending|Delayed) sleep 20;; *) echo \"Updates status: $ST\"; exit 1;; esac; done",
      "[ \"$ST\" = Success ] || { echo 'Updates did not succeed'; exit 1; }",
    ]
  }

  # 2) Minimal post-update hardening via SSM PowerShell
  provisioner "shell-local" {
    environment_vars = [
      "AWS_REGION=${var.aws_region}",
      "BUILD_TOKEN={{timestamp}}",
    ]
    inline = [
      "set -euo pipefail",
      "INSTANCE_ID=$(aws ec2 describe-instances --region $AWS_REGION --filters Name=tag:BuildToken,Values=$BUILD_TOKEN Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[].InstanceId' --output text | head -n1)",
      "JSON='{\"commands\": [\"Enable-NetFirewallRule -DisplayGroup ''Remote Desktop''\", \"Set-Service -Name AmazonSSMAgent -StartupType Automatic\"]}'",
      "CMD_ID=$(aws ssm send-command --region $AWS_REGION --instance-ids $INSTANCE_ID --document-name AWS-RunPowerShellScript --parameters \"$JSON\" --query Command.CommandId --output text)",
      "for i in $(seq 1 60); do ST=$(aws ssm list-command-invocations --region $AWS_REGION --command-id $CMD_ID --details --query 'CommandInvocations[0].Status' --output text 2>/dev/null || true); case \"$ST\" in Success) echo 'Post-hardening Success'; break;; InProgress|Pending|Delayed) sleep 10;; *) echo \"PS status: $ST\"; exit 1;; esac; done",
      "[ \"$ST\" = Success ] || { echo 'Post-hardening did not succeed'; exit 1; }",
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        "set -euo pipefail",
        "ART='{{ .ArtifactId }}'",
        "echo Artifact: $ART",
        "AMI_ID=$(echo \"$ART\" | grep -Eo 'ami-[a-f0-9]+' | head -n1)",
        "[ -n \"$AMI_ID\" ] || { echo 'AMI_ID not found in ArtifactId'; exit 1; }",
        "if [ -n \"${var.ssm_publish_path}\" ]; then \\",
        "  aws ssm put-parameter --region ${var.aws_region} --name ${var.ssm_publish_path} --type String --overwrite --value $AMI_ID >/dev/null && echo Published $AMI_ID to ${var.ssm_publish_path}; \\",
        "else echo 'Skipping SSM publish; ssm_publish_path not set'; fi",
      ]
    }
  }
}
