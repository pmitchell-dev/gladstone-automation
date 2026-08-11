#!/usr/bin/env python3
"""
==========================================================
GLADSTONE GEMINI API BACKEND SERVICE (gemini_api_server.py)
==========================================================
Version: 1.1.0
Purpose: Provides a lightweight CORS-enabled HTTP proxy for local websites
         to send prompts to Google Gemini API without exposing the API key.
         Attempts gemini-flash-latest first, with fallback to gemini-flash-latest.
Endpoint: POST /api/query
Payload:  {"prompt": "...", "model": "gemini-flash-latest", "system_instruction": "..."}
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
DEFAULT_MODEL = os.environ.get("GEMINI_DEFAULT_MODEL", "gemini-flash-latest").strip()
FALLBACK_MODEL = os.environ.get("GEMINI_FALLBACK_MODEL", "gemini-flash-latest").strip()

GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint for Docker container and monitoring."""
    has_key = bool(GEMINI_API_KEY and GEMINI_API_KEY != "your_gemini_api_key_here")
    return jsonify({
        "status": "ok",
        "service": "gemini-api-backend",
        "api_key_configured": has_key,
        "default_model": DEFAULT_MODEL,
        "fallback_model": FALLBACK_MODEL
    }), 200


@app.route("/api/query", methods=["POST"])
def query_gemini():
    """
    Query Gemini API endpoint with automatic fallback.
    JSON Body:
      - prompt (required): string text prompt
      - model (optional): string model name (default: gemini-flash-latest)
      - system_instruction (optional): string system instruction
      - image_base64 (optional): base64 encoded image string
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

    primary_model = data.get("model", DEFAULT_MODEL).strip()
    system_instruction = data.get("system_instruction", "").strip()
    image_base64 = data.get("image_base64", "").strip()

    # Construct payload parts
    parts = [{"text": prompt}]
    if image_base64:
        if "," in image_base64:
            image_base64 = image_base64.split(",", 1)[1]
        parts.append({
            "inline_data": {
                "mime_type": "image/jpeg",
                "data": image_base64
            }
        })

    gemini_payload = {
        "contents": [
            {
                "parts": parts
            }
        ]
    }

    if system_instruction:
        gemini_payload["system_instruction"] = {
            "parts": [
                {"text": system_instruction}
            ]
        }

    # Build sequence of models to attempt (primary model -> fallback model)
    models_to_try = [primary_model]
    if FALLBACK_MODEL and primary_model != FALLBACK_MODEL:
        models_to_try.append(FALLBACK_MODEL)

    last_error_response = None

    for idx, current_model in enumerate(models_to_try):
        url = f"{GEMINI_BASE_URL}/{current_model}:generateContent?key={GEMINI_API_KEY}"
        headers = {"Content-Type": "application/json"}

        try:
            logging.info(f"Sending prompt to Gemini API (model: {current_model})...")
            response = requests.post(url, headers=headers, json=gemini_payload, timeout=30)

            if response.status_code == 200:
                res_data = response.json()
                result_text = ""
                candidates = res_data.get("candidates", [])
                if candidates:
                    c_parts = candidates[0].get("content", {}).get("parts", [])
                    if c_parts:
                        result_text = c_parts[0].get("text", "")

                return jsonify({
                    "status": "success",
                    "result": result_text,
                    "model": current_model,
                    "raw": res_data
                }), 200

            err_msg = response.text
            logging.warning(f"Gemini API model '{current_model}' returned status {response.status_code}: {err_msg}")

            last_error_response = (jsonify({
                "status": "error",
                "message": f"Gemini API error ({response.status_code}) on model '{current_model}'",
                "details": response.json() if response.headers.get("content-type") == "application/json" else err_msg
            }), response.status_code)

        except requests.exceptions.Timeout:
            logging.warning(f"Timeout connecting to Gemini API with model '{current_model}'.")
            last_error_response = (jsonify({
                "status": "error",
                "message": f"Request to Gemini API timed out after 30 seconds for model '{current_model}'."
            }), 504)
        except Exception as e:
            logging.exception(f"Unexpected error calling Gemini API with model '{current_model}'")
            last_error_response = (jsonify({
                "status": "error",
                "message": f"Server error on model '{current_model}': {str(e)}"
            }), 500)

        # Log fallback attempt if there is a next model in the list
        if idx < len(models_to_try) - 1:
            next_model = models_to_try[idx + 1]
            logging.warning(f"Attempting fallback from model '{current_model}' to '{next_model}'...")

    return last_error_response


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5050))
    app.run(host="0.0.0.0", port=port, debug=False)
