#!/usr/bin/env python3
"""
==========================================================
GLADSTONE GEMINI API BACKEND SERVICE (gemini_api_server.py)
==========================================================
Version: 1.0.0
Purpose: Provides a lightweight CORS-enabled HTTP proxy for local websites
         to send prompts to Google Gemini API without exposing the API key.
Endpoint: POST /api/query
Payload:  {"prompt": "...", "model": "gemini-2.5-flash", "system_instruction": "..."}
==========================================================
"""

import os
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
import requests

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

app = Flask(__name__)
# Enable CORS for all routes (allows calls from local websites running on any port/origin)
CORS(app, resources={r"/api/*": {"origins": "*"}})

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()
DEFAULT_MODEL = os.environ.get("GEMINI_DEFAULT_MODEL", "gemini-2.5-flash").strip()

GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint for Docker container and monitoring."""
    has_key = bool(GEMINI_API_KEY and GEMINI_API_KEY != "your_gemini_api_key_here")
    return jsonify({
        "status": "ok",
        "service": "gemini-api-backend",
        "api_key_configured": has_key,
        "default_model": DEFAULT_MODEL
    }), 200


@app.route("/api/query", methods=["POST"])
def query_gemini():
    """
    Query Gemini API endpoint.
    JSON Body:
      - prompt (required): string text prompt
      - model (optional): string model name (e.g. gemini-2.5-flash, gemini-1.5-flash, gemini-1.5-pro)
      - system_instruction (optional): string system instruction
    """
    if not GEMINI_API_KEY or GEMINI_API_KEY == "your_gemini_api_key_here":
        logging.error("GEMINI_API_KEY is not set or holds placeholder value.")
        return jsonify({
            "status": "error",
            "message": "GEMINI_API_KEY is not configured on the webhost server. Please set it in ~/gemini-api/.env"
        }), 500

    data = request.get_json(silent=True)
    if not data or "prompt" not in data:
        return jsonify({
            "status": "error",
            "message": "Missing required field 'prompt' in JSON request body."
        }), 400

    prompt = str(data["prompt"]).strip()
    if not prompt:
        return jsonify({
            "status": "error",
            "message": "'prompt' field cannot be empty."
        }), 400

    model = data.get("model", DEFAULT_MODEL).strip()
    system_instruction = data.get("system_instruction", "").strip()

    # Construct payload for Google Gemini REST API
    gemini_payload = {
        "contents": [
            {
                "parts": [
                    {"text": prompt}
                ]
            }
        ]
    }

    if system_instruction:
        gemini_payload["system_instruction"] = {
            "parts": [
                {"text": system_instruction}
            ]
        }

    url = f"{GEMINI_BASE_URL}/{model}:generateContent?key={GEMINI_API_KEY}"
    headers = {"Content-Type": "application/json"}

    try:
        logging.info(f"Sending prompt to Gemini API (model: {model})...")
        response = requests.post(url, headers=headers, json=gemini_payload, timeout=30)
        
        if response.status_code != 200:
            logging.error(f"Gemini API returned status code {response.status_code}: {response.text}")
            return jsonify({
                "status": "error",
                "message": f"Gemini API error ({response.status_code})",
                "details": response.json() if response.headers.get("content-type") == "application/json" else response.text
            }), response.status_code

        res_data = response.json()
        
        # Extract response text
        result_text = ""
        candidates = res_data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            if parts:
                result_text = parts[0].get("text", "")

        return jsonify({
            "status": "success",
            "result": result_text,
            "model": model,
            "raw": res_data
        }), 200

    except requests.exceptions.Timeout:
        logging.error("Timeout occurred while connecting to Gemini API.")
        return jsonify({
            "status": "error",
            "message": "Request to Gemini API timed out after 30 seconds."
        }), 504
    except Exception as e:
        logging.exception("Unexpected error while calling Gemini API")
        return jsonify({
            "status": "error",
            "message": f"Server error: {str(e)}"
        }), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5050))
    app.run(host="0.0.0.0", port=port, debug=False)
