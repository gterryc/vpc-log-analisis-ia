# Output para mostrar IPs y comandos útiles
# output "demo_info" {
#   value = {
#     web_server_private_ip       = aws_instance.web_server.private_ip
#     attack_simulator_public_ip  = aws_eip.attack_simulator.public_ip
#     attack_simulator_private_ip = aws_instance.attack_simulator.private_ip

#     ssh_command = "ssh -i your-key.pem ec2-user@${aws_eip.attack_simulator.public_ip}"

#     attack_commands = {
#       port_scan         = "./attack_controller.sh port",
#       ddos              = "./attack_controller.sh ddos",
#       data_exfiltration = "./attack_controller.sh exfil",
#       all_attacks       = "./attack_controller.sh all",
#       stop_attacks      = "./attack_controller.sh stop"
#     }
#   }
# }