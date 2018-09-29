{
    "server": false,
    "datacenter": "${CONSUL_DC}",
    "client_addr": "${CONSUL_CLIENT_ADDR}",
    "data_dir": "/consul/data",
    "encrypt": "${CONSUL_ENCRYPT}",
    "log_level": "ERR",
    "start_join": ["${CONSUL_SERVER}"],
    "enable_script_checks": true
}