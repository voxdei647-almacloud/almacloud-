from typing import Dict, Any, Optional


def parse_eve_event(raw_eve: Dict[str, Any]) -> Dict[str, Any]:
    event_type = raw_eve.get("event_type", "unknown")
    severity_mapping = {
        1: "critical",
        2: "high",
        3: "medium",
        4: "low"
    }

    src_ip = raw_eve.get("src_ip")
    dest_ip = raw_eve.get("dest_ip")

    parsed = {
        "event_type": f"suricata.{event_type}",
        "source_ip": src_ip,
        "destination_ip": dest_ip,
        "severity": "info",
        "raw_event": raw_eve
    }

    if event_type == "alert":
        alert_info = raw_eve.get("alert", {})
        severity_num = alert_info.get("severity", 3)
        parsed["severity"] = severity_mapping.get(severity_num, "medium")
        parsed["signature"] = alert_info.get("signature", "Sin firma")
        parsed["category"] = alert_info.get("category", "Uncategorized")
    elif event_type == "dns":
        parsed["severity"] = "info"
        parsed["query"] = raw_eve.get("dns", {}).get("rrname")
    elif event_type == "http":
        parsed["severity"] = "info"
        parsed["hostname"] = raw_eve.get("http", {}).get("hostname")

    return parsed
