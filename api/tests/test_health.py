from datetime import datetime


def test_health_returns_200(client):
    resp = client.get("/health")
    assert resp.status_code == 200


def test_health_response_shape(client):
    resp = client.get("/health")
    body = resp.json()
    assert body["status"] == "ok"
    assert body["service"] == "homepage-api"
    assert "time" in body


def test_health_time_is_parseable_iso8601_utc(client):
    resp = client.get("/health")
    time_value = resp.json()["time"]
    parsed = datetime.fromisoformat(time_value)
    assert parsed.tzinfo is not None
