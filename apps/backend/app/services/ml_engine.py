import logging
import numpy as np
from typing import Dict, Any, List
from sklearn.ensemble import IsolationForest
from sklearn.cluster import KMeans

logger = logging.getLogger(__name__)


class MLInferenceEngine:
    _iso_forest: IsolationForest = None
    _kmeans: KMeans = None

    @classmethod
    def _initialize_models(cls):
        """Inicializa los modelos no supervisados con un baseline de comportamiento de red."""
        if cls._iso_forest is None:
            # Baseline sintético de tráfico normal (features: [dest_port, payload_size, rate, severity_code])
            normal_traffic = np.random.normal(loc=[80, 500, 10, 1], scale=[10, 100, 2, 0.5], size=(200, 4))
            
            cls._iso_forest = IsolationForest(n_estimators=100, contamination=0.05, random_state=42)
            cls._iso_forest.fit(normal_traffic)

            cls._kmeans = KMeans(n_clusters=3, random_state=42)
            cls._kmeans.fit(normal_traffic)

    @classmethod
    def _extract_features(cls, event: Dict[str, Any]) -> np.ndarray:
        """Extrae el vector numérico de características desde la telemetría o logs Suricata."""
        raw = event.get("raw_event", {})
        if not isinstance(raw, dict):
            raw = {}
        
        dest_port = raw.get("dest_port", 80)
        bytes_len = raw.get("payload_printable", "") or str(raw)
        payload_size = len(bytes_len)
        
        severity_map = {"low": 1, "medium": 2, "high": 3, "critical": 4}
        sev_code = severity_map.get(str(event.get("severity", "info")).lower(), 1)
        
        rate = 15.0 if sev_code >= 3 else 2.0

        return np.array([[dest_port, payload_size, rate, sev_code]])

    @classmethod
    def calculate_risk_level(cls, anomaly_score: float) -> str:
        """Clasifica el Nivel de Riesgo operativo en función del score de anomalía."""
        if anomaly_score >= 0.85:
            return "CRITICAL"
        elif anomaly_score >= 0.65:
            return "HIGH"
        elif anomaly_score >= 0.40:
            return "MEDIUM"
        else:
            return "LOW"

    @classmethod
    def evaluate_event(cls, event: Dict[str, Any]) -> Dict[str, Any]:
        """Evalúa un evento individual con IsolationForest y KMeans."""
        cls._initialize_models()
        
        features = cls._extract_features(event)
        
        prediction = cls._iso_forest.predict(features)[0]
        decision_score = cls._iso_forest.decision_function(features)[0]
        
        # Normalización del Score de Anomalía entre 0.0 y 1.0
        anomaly_score = float(np.clip(0.5 - (decision_score * 2), 0.0, 1.0))
        cluster_id = int(cls._kmeans.predict(features)[0])
        risk_level = cls.calculate_risk_level(anomaly_score)

        return {
            "anomaly_score": round(anomaly_score, 4),
            "is_anomaly": bool(prediction == -1 or anomaly_score > 0.60),
            "cluster_id": cluster_id,
            "risk_level": risk_level
        }

    @classmethod
    def generate_batch_statistics(cls, evaluation_results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula estadísticas descriptivas sobre el lote evaluado por el modelo ML."""
        if not evaluation_results:
            return {"total_evaluated": 0}

        scores = [res["anomaly_score"] for res in evaluation_results]
        risks = [res["risk_level"] for res in evaluation_results]

        return {
            "total_evaluated": len(scores),
            "mean_anomaly_score": round(float(np.mean(scores)), 4),
            "max_anomaly_score": round(float(np.max(scores)), 4),
            "risk_distribution": {
                "critical": risks.count("CRITICAL"),
                "high": risks.count("HIGH"),
                "medium": risks.count("MEDIUM"),
                "low": risks.count("LOW")
            }
        }
