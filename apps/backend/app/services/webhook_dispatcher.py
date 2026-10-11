import logging
import asyncio
import aiohttp
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class WebhookDispatcher:
    @classmethod
    async def send_alert_webhook(cls, webhook_url: Optional[str], alert: Dict[str, Any]) -> bool:
        if not webhook_url:
            logger.info("No se definió URL de Webhook. Omitiendo notificación externa.")
            return False

        payload = {
            "content": f"🚨 **ALMA SOC ALERT TRIGGERED** [{alert.get('severity', '').upper()}]",
            "embeds": [
                {
                    "title": alert.get("rule_name", "Alerta de Ciberseguridad"),
                    "color": 15158332 if alert.get("severity") == "critical" else 15105570,
                    "fields": [
                        {"name": "Tenant ID", "value": alert.get("tenant_id", "N/A"), "inline": True},
                        {"name": "Severidad", "value": alert.get("severity", "N/A").upper(), "inline": True},
                        {"name": "Origen IP", "value": alert.get("source_ip", "N/A"), "inline": True},
                        {"name": "Destino IP", "value": alert.get("destination_ip", "N/A"), "inline": True},
                        {"name": "Timestamp", "value": alert.get("triggered_at", "N/A"), "inline": False}
                    ]
                }
            ]
        }

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(webhook_url, json=payload, timeout=5) as resp:
                    if resp.status in (200, 204):
                        logger.info(f"Notificación de alerta enviada exitosamente a Webhook ({resp.status}).")
                        return True
                    else:
                        logger.warning(f"Error respondiendo Webhook: HTTP {resp.status}")
                        return False
        except Exception as exc:
            logger.error(f"Excepción al despachar Webhook: {exc}")
            return False
