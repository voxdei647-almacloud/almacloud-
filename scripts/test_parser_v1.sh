#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"

python3 -c "
from app.services.suricata_parser import parse_eve_event

sample_eve = {
    'event_type': 'alert',
    'src_ip': '192.168.1.100',
    'dest_ip': '10.0.0.1',
    'alert': {
        'action': 'allowed',
        'gid': 1,
        'signature_id': 2000001,
        'rev': 1,
        'signature': 'ET MALWARE Suspicious User-Agent',
        'category': 'A Network Trojan was detected',
        'severity': 1
    }
}

result = parse_eve_event(sample_eve)
assert result['event_type'] == 'suricata.alert'
assert result['severity'] == 'critical'
assert result['source_ip'] == '192.168.1.100'
print('PASS PARSER1: Parseo y mapeo de severidad de evento Suricata EVE correcto')
"
