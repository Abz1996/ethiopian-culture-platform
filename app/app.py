"""Habesha Kitchen - a tiny API + site about Ethiopian food and culture."""
import json
import os
from pathlib import Path

from flask import Flask, abort, jsonify, render_template, request

BASE = Path(__file__).parent
DATA = BASE / "data"

app = Flask(__name__)


def _load(name):
    with open(DATA / name, encoding="utf-8") as fh:
        return json.load(fh)


DISHES = _load("dishes.json")
CULTURE = _load("culture.json")
ENVIRONMENT = os.getenv("ENVIRONMENT", "local")
VERSION = os.getenv("APP_VERSION", "dev")


@app.get("/")
def index():
    return render_template(
        "index.html",
        dishes=DISHES,
        traditions=CULTURE["traditions"],
        holidays=CULTURE["holidays"],
        environment=ENVIRONMENT,
        version=VERSION,
    )


@app.get("/api/dishes")
def list_dishes():
    items = DISHES
    category = request.args.get("category")
    if category:
        items = [d for d in items if d["category"] == category]
    if request.args.get("fasting") == "true":
        items = [d for d in items if d["fasting_friendly"]]
    return jsonify(items)


@app.get("/api/dishes/<slug>")
def get_dish(slug):
    for dish in DISHES:
        if dish["slug"] == slug:
            return jsonify(dish)
    abort(404)


@app.get("/api/culture")
def culture():
    return jsonify(CULTURE["traditions"])


@app.get("/api/holidays")
def holidays():
    return jsonify(CULTURE["holidays"])


@app.get("/healthz")
def healthz():
    return jsonify(status="ok", environment=ENVIRONMENT, version=VERSION)


@app.errorhandler(404)
def not_found(_):
    return jsonify(error="not found"), 404


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
