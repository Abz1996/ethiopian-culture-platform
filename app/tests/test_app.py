import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import app  # noqa: E402

client = app.test_client()


def test_health():
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"


def test_dishes_list_and_filter():
    all_dishes = client.get("/api/dishes").get_json()
    assert len(all_dishes) >= 10
    fasting = client.get("/api/dishes?fasting=true").get_json()
    assert fasting and all(d["fasting_friendly"] for d in fasting)
    drinks = client.get("/api/dishes?category=drink").get_json()
    assert {d["slug"] for d in drinks} >= {"tej", "buna"}


def test_single_dish_and_404():
    assert client.get("/api/dishes/doro-wat").get_json()["name"] == "Doro Wat"
    assert client.get("/api/dishes/pizza").status_code == 404


def test_culture_and_holidays():
    slugs = {t["slug"] for t in client.get("/api/culture").get_json()}
    assert "coffee-ceremony" in slugs
    holidays = {h["slug"] for h in client.get("/api/holidays").get_json()}
    assert {"enkutatash", "meskel", "timkat"} <= holidays


def test_index_page():
    r = client.get("/")
    assert r.status_code == 200
    assert b"Habesha Kitchen" in r.data
