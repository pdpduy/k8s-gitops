#cloud-config
hostname: ${hostname}
fqdn: ${fqdn}
manage_etc_hosts: false

write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1   localhost
      127.0.1.1   ${fqdn} ${hostname}
${hosts_entries}

runcmd:
  - mkdir -p /root/.ssh
  - cp /home/${admin_username}/.ssh/authorized_keys /root/.ssh/authorized_keys
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/authorized_keys
  - chown -R root:root /root/.ssh
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  - systemctl restart ssh