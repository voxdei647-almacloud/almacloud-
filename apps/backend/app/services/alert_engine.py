import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


class AlertRuleEngine:
    CRITICAL_SEVERITIES = {"critical", "high"}

    @classmethod
    def evaluate_event(cls, tenant_id: str, event: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        severity = event.get("severity", "info").lower()
        if severity not in cls.CRITICAL_SEVERITIES:
            return None

        alert_id = f"alt_{int(datetime.now(timezone.utc).timestamp() * 1000)}"
        return {
            "alert_id": alert_id,
            "tenant_id": tenant_id,
            "rule_name": f"High Severity Detection: {event.get('event_type')}",
            "severity": severity,
            "source_ip": event.get("source_ip"),
            "destination_ip": event.get("destination_ip"),
            "raw_event": event.get("raw_event", {}),
            "triggered_at": datetime.now(timezone.utc).isoformat()
        }

    @classmethod
    def process_batch(cls, tenant_id: str, events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        alerts = []
        for ev in events:
            alert = cls.evaluate_event(tenant_id, ev)
            if alert:
                alerts.append(alert)
        return alerts
