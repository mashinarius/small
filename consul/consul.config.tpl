{
    "server": true,
    "bootstrap_expect": 1,
    "ports" : {
        "dns":53
    },
    "recursors" : ["8.8.8.8"],
    "datacenter": "${CONSUL_DC}",
    "data_dir": "/consul/data",
    "encrypt": "${CONSUL_ENCRYPT}",
    "log_level": "ERR",
    "enable_script_checks": true,
    "ui": true
}