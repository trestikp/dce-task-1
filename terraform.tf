
terraform {
  required_providers {
    opennebula = {
      source = "OpenNebula/opennebula"
      version = "~> 1.2"
    }
  }
}
provider "opennebula" {
  endpoint      = "${var.one_endpoint}"
  username      = "${var.one_username}"
  password      = "${var.one_password}"
}

# resource "opennebula_image" "os-image" {
#     name = "${var.vm_image_name}"
#     datastore_id = "${var.vm_imagedatastore_id}"
#     persistent = false
#     path = "${var.vm_image_url}"
#     permissions = "600"
# }

resource "opennebula_virtual_machine" "frontend-node" {
  # This will create `vm_instance_count` instances:
  name = "frontend-node"
  description = "Frontend and load balancer VM"
  cpu = 1
  vcpu = 1
  memory = 2048
  permissions = "600"
  group = "users"

  context = {
    NETWORK  = "YES"
    HOSTNAME = "$NAME"
    SSH_PUBLIC_KEY = "${var.vm_ssh_pubkey}"
  }
  os {
    arch = "x86_64"
    boot = "disk0"
  }
  disk {
    # image_id = opennebula_image.os-image.id
    image_id = 422
    target   = "vda"
    size     = 12000 # 12GB
  }

  graphics {
    listen = "0.0.0.0"
    type   = "vnc"
  }

  nic {
    network_id = var.vm_network_id
  }

  connection {
    type = "ssh"
    user = "root"
    host = "${self.ip}"
    private_key = "${file("/var/iac-dev-container-data/id_ecdsa")}"
  }

  provisioner "file" {
    source = "init-scripts/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "export INIT_USER=${var.vm_admin_user}",
      "export INIT_PUBKEY='${var.vm_ssh_pubkey}'",
      "export INIT_LOG=${var.vm_node_init_log}",
      "export INIT_HOSTNAME=${self.name}",
      "touch ${var.vm_node_init_log}",
      "sh /tmp/init-start.sh",
      "sh /tmp/init-node.sh",
      "sh /tmp/init-users.sh",
      "sh /tmp/init-finish.sh"
    ]
  }

  tags = {
    role = "master"
  }

}

resource "opennebula_virtual_machine" "backend-node" {
  # This will create `vm_instance_count` instances:
  count = var.nodes_count
  name = "backend-node-${count.index + 1}"
  description = "Backend node VM #${count.index + 1}"
  cpu = 1
  vcpu = 1
  memory = 2048
  permissions = "600"
  group = "users"

  context = {
    NETWORK  = "YES"
    HOSTNAME = "$NAME"
    SSH_PUBLIC_KEY = "${var.vm_ssh_pubkey}"
  }
  os {
    arch = "x86_64"
    boot = "disk0"
  }
  disk {
    # image_id = opennebula_image.os-image.id
    image_id = 422
    target   = "vda"
    size     = 12000 # 12GB
  }

  graphics {
    listen = "0.0.0.0"
    type   = "vnc"
  }

  nic {
    network_id = var.vm_network_id
  }

  connection {
    type = "ssh"
    user = "root"
    host = "${self.ip}"
    private_key = "${file("/var/iac-dev-container-data/id_ecdsa")}"
  }

  provisioner "file" {
    source = "init-scripts/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "export INIT_USER=${var.vm_admin_user}",
      "export INIT_PUBKEY='${var.vm_ssh_pubkey}'",
      "export INIT_LOG=${var.vm_node_init_log}",
      "export INIT_HOSTNAME=${self.name}",
      "touch ${var.vm_node_init_log}",
      "sh /tmp/init-start.sh",
      "sh /tmp/init-node.sh",
      "sh /tmp/init-users.sh",
      "sh /tmp/init-finish.sh"
    ]
  }

  tags = {
    role = "node"
  }

}

#-------OUTPUTS ------------

output "frontend-node" {
  value = "${opennebula_virtual_machine.frontend-node.*.ip}"
}

output "backend-nodes" {
  value = "${opennebula_virtual_machine.backend-node.*.ip}"
}

resource "null_resource" "wait_for_all_nodes_ssh" {
  # This is used because init-scripts schedule a restart after 1 minute. The instances are unavailable for this time +
  # the boot time. This can cause other following resources to crash, so this script tests SSH connection to ALL
  # instances until all SSH for admin accounts are working
  # 
  # The timeout in the init scripts could probably be changed to immediate restart saving us 1 minute

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash

      ips_arr=($ALL_IPS)

      # Function to check if SSH connection is available
      check_ssh_connection() {
          all_work=0

          for ip in $${ips_arr[@]}; do
              echo "Testing $ip"

              if ! ssh -o "StrictHostKeyChecking no" -o ConnectTimeout=5 -o BatchMode=yes "nodeadm@$ip" "echo 2>&1"; then
                  all_work=1
                  echo "$ip is not responding"
                  break
              fi
          done

          return $all_work
      }

      until check_ssh_connection; do
          sleep 5
      done
    EOT

    interpreter = [ "bash", "-c" ]
    environment = {
      SSH_USER = var.vm_admin_user
      ALL_IPS = "${join(" ", concat(opennebula_virtual_machine.frontend-node.*.ip, opennebula_virtual_machine.backend-node.*.ip))}"
    }
  }
}

resource "local_file" "hosts_cfg" {
  depends_on = [ null_resource.wait_for_all_nodes_ssh ]

  content = templatefile("inventory.tmpl",
    {
      vm_admin_user = var.vm_admin_user,
      frontend_nodes = opennebula_virtual_machine.frontend-node.*.ip,
      backend_nodes = opennebula_virtual_machine.backend-node.*.ip
    })
  filename = "./dynamic_inventories/semestral_task"
}

resource "local_file" "nginx_upstream_cfg" {
  depends_on = [ local_file.hosts_cfg ]

  content = templatefile("./demo-3/frontend/config/backend-upstream.conf.tmpl",
    {
      backend_nodes = opennebula_virtual_machine.backend-node.*.ip
    })
  filename = "./demo-3/frontend/config/backend-upstream.conf"
}

resource "null_resource" "run_ansible" {
  depends_on = [ local_file.nginx_upstream_cfg ]

  # the timeout is a failsafe for ansible - first ssh connection can take a long time
  provisioner "local-exec" {
    command = "ansible-playbook -T 30 -i dynamic_inventories/semestral_task ansible/semestral-task.yml"
    # environment = {
    #   ANSIBLE_HOST_KEY_CHECKING=false
    # }
  }
}


#
# EOF
#
