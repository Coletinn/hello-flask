all:
  hosts:
    flask_server:
      ansible_host: ${host_ip}
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ../aws-keypair.pem
      ansible_python_interpreter: /usr/bin/python3