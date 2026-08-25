#!/usr/bin/env python3
"""
==========================================================
GLADSTONE GEMINI API BACKEND SERVICE (gemini_api_server.py)
==========================================================
Version: 1.4.0
Purpose: Provides a lightweight CORS-enabled HTTP proxy for local websites
         to send prompts to Google Gemini API without exposing the API key.
         Features global request time budgeting (prevents Gunicorn worker timeouts),
         exponential backoff with full jitter, Retry-After parsing,
         and rapid multi-tier cost-ordered model fallback across Gemini 3.1 Flash-Lite,
         2.5 Flash, 3.5 Flash, 3.6 Flash, and 3.7 Flash.
Endpoint: POST /api/query
Payload:  {"prompt": "...", "model": "gemini-3.1-flash-lite", "system_instruction": "..."}
==========================================================
"""

import os
import time
import random
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
DEFAULT_MODEL = os.environ.get("GEMINI_DEFAULT_MODEL", "gemini-3.1-flash-lite").strip()
FALLBACK_MODEL = os.environ.get("GEMINI_FALLBACK_MODEL", "gemini-2.5-flash").strip()

GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

MAX_RETRIES_PER_MODEL = int(os.environ.get("GEMINI_MAX_RETRIES", "2"))
MAX_TOTAL_REQUEST_TIMEOUT = int(os.environ.get("GEMINI_MAX_REQUEST_TIMEOUT", "45"))
PER_REQUEST_HTTP_TIMEOUT = int(os.environ.get("GEMINI_HTTP_TIMEOUT", "12"))

RETRYABLE_STATUS_CODES = {408, 428, 429, 500, 502, 503, 504}
RETRYABLE_ERROR_KEYWORDS = {"resource_exhausted", "unavailable", "overloaded", "busy", "capacity_exceeded", "rate limit"}

# Canonical cost-ascending model hierarchy pool for fallback cascade (cheapest first, most expensive last)
MODEL_HIERARCHY = ["gemini-3.1-flash-lite", "gemini-2.5-flash", "gemini-3.5-flash", "gemini-3.6-flash", "gemini-3.7-flash"]


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint for Docker container and monitoring."""
    has_key = bool(GEMINI_API_KEY and GEMINI_API_KEY != "your_gemini_api_key_here")
    return jsonify({
        "status": "ok",
        "service": "gemini-api-backend",
        "api_key_configured": has_key,
        "default_model": DEFAULT_MODEL,
        "fallback_model": FALLBACK_MODEL,
        "max_retries_per_model": MAX_RETRIES_PER_MODEL,
        "max_global_timeout": MAX_TOTAL_REQUEST_TIMEOUT,
        "model_hierarchy": MODEL_HIERARCHY
    }), 200


def calculate_backoff(attempt: int, response_headers: dict = None) -> float:
    """Calculate exponential backoff delay with full jitter and Retry-After header support."""
    base_delay = min(2 ** (attempt - 1), 4)
    jitter_delay = random.uniform(0.5, 1.5) * base_delay

    if response_headers:
        retry_after_hdr = response_headers.get("Retry-After") or response_headers.get("retry-after")
        if retry_after_hdr:
            try:
                retry_after_sec = float(retry_after_hdr)
                if 0 < retry_after_sec <= 10:
                    return max(jitter_delay, retry_after_sec + random.uniform(0.1, 0.5))
            except ValueError:
                pass

    return jitter_delay


@app.route("/api/query", methods=["POST"])
def query_gemini():
    """
    Query Gemini API endpoint with automatic multi-tier fallback and request time budgeting.
    JSON Body:
      - prompt (required): string text prompt
      - model (optional): string model name (default: gemini-3.1-flash-lite)
      - system_instruction (optional): string system instruction
      - image_base64 (optional): base64 encoded image string
    """
    start_time = time.time()

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
    if primary_model == "gemini-flash-latest":
        primary_model = DEFAULT_MODEL

    system_instruction = data.get("system_instruction", "").strip()
    image_base64 = data.get("image_base64", "").strip()

    # Construct payload parts
    parts = [{"text": prompt}]
    mime_type = "image/jpeg"
    if image_base64:
        if image_base64.startswith("data:"):
            try:
                header, image_base64 = image_base64.split(",", 1)
                if ";" in header and ":" in header:
                    mime_type = header.split(";")[0].split(":")[1]
            except Exception:
                pass
        elif "," in image_base64:
            image_base64 = image_base64.split(",", 1)[1]

        parts.append({
            "inlineData": {
                "mimeType": mime_type,
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

    # Build sequence of models to attempt (primary model -> fallback pool)
    models_to_try = [primary_model]

    if FALLBACK_MODEL and FALLBACK_MODEL not in models_to_try:
        models_to_try.append(FALLBACK_MODEL)

    for tier_model in MODEL_HIERARCHY:
        if tier_model not in models_to_try:
            models_to_try.append(tier_model)

    last_error_response = None

    for idx, current_model in enumerate(models_to_try):
        url = f"{GEMINI_BASE_URL}/{current_model}:generateContent?key={GEMINI_API_KEY}"
        headers = {"Content-Type": "application/json"}

        for attempt in range(1, MAX_RETRIES_PER_MODEL + 1):
            elapsed = time.time() - start_time
            remaining_budget = MAX_TOTAL_REQUEST_TIMEOUT - elapsed

            if remaining_budget <= 3:
                logging.warning(f"Global request time budget ({MAX_TOTAL_REQUEST_TIMEOUT}s) nearly exhausted ({elapsed:.1f}s elapsed). Stopping retries.")
                break

            req_timeout = max(3, min(PER_REQUEST_HTTP_TIMEOUT, int(remaining_budget - 1)))

            try:
                logging.info(f"=== PROMPT SENT TO GEMINI (model: {current_model}, attempt: {attempt}/{MAX_RETRIES_PER_MODEL}, timeout: {req_timeout}s) ===")
                if system_instruction:
                    logging.info(f"System Instruction: {system_instruction}")
                logging.info(f"Prompt: {prompt}")
                if image_base64:
                    logging.info(f"[IMAGE ATTACHED] mimeType: {mime_type}, base64 length: {len(image_base64)} chars")
                else:
                    logging.info("[NO IMAGE ATTACHED]")

                response = requests.post(url, headers=headers, json=gemini_payload, timeout=req_timeout)

                if response.status_code == 200:
                    res_data = response.json()
                    result_text = ""
                    candidates = res_data.get("candidates", [])
                    if candidates:
                        c_parts = candidates[0].get("content", {}).get("parts", [])
                        if c_parts:
                            result_text = c_parts[0].get("text", "")

                    logging.info(f"=== RESPONSE RETRIEVED FROM GEMINI (model: {current_model}) in {time.time() - start_time:.2f}s ===")
                    logging.info(f"Response: {result_text}")

                    return jsonify({
                        "status": "success",
                        "result": result_text,
                        "model": current_model,
                        "raw": res_data
                    }), 200

                err_msg = response.text
                logging.warning(f"=== ERROR RESPONSE FROM GEMINI (model: {current_model}, status: {response.status_code}, attempt: {attempt}/{MAX_RETRIES_PER_MODEL}) ===")
                logging.warning(f"Error Details: {err_msg}")

                last_error_response = (jsonify({
                    "status": "error",
                    "message": f"Gemini API error ({response.status_code}) on model '{current_model}' after {attempt} attempt(s)",
                    "details": response.json() if response.headers.get("content-type") == "application/json" else err_msg
                }), response.status_code)

                # Check if response status code or error payload indicates retryable capacity/rate error
                is_retryable = response.status_code in RETRYABLE_STATUS_CODES
                if not is_retryable and err_msg:
                    err_msg_lower = err_msg.lower()
                    if any(kw in err_msg_lower for kw in RETRYABLE_ERROR_KEYWORDS):
                        is_retryable = True

                if is_retryable and attempt < MAX_RETRIES_PER_MODEL:
                    sleep_seconds = calculate_backoff(attempt, response.headers)
                    if time.time() - start_time + sleep_seconds < MAX_TOTAL_REQUEST_TIMEOUT - 2:
                        logging.warning(f"Retryable error status {response.status_code} encountered. Backing off (full jitter) for {sleep_seconds:.2f}s before attempt {attempt + 1}/{MAX_RETRIES_PER_MODEL}...")
                        time.sleep(sleep_seconds)
                        continue

                break

            except requests.exceptions.Timeout:
                logging.warning(f"Timeout ({req_timeout}s) connecting to Gemini API with model '{current_model}' (attempt {attempt}/{MAX_RETRIES_PER_MODEL}).")
                last_error_response = (jsonify({
                    "status": "error",
                    "message": f"Request to Gemini API timed out after {req_timeout} seconds for model '{current_model}'."
                }), 504)
                if attempt < MAX_RETRIES_PER_MODEL:
                    sleep_seconds = calculate_backoff(attempt)
                    if time.time() - start_time + sleep_seconds < MAX_TOTAL_REQUEST_TIMEOUT - 2:
                        logging.warning(f"Backing off (full jitter) for {sleep_seconds:.2f}s before attempt {attempt + 1}/{MAX_RETRIES_PER_MODEL}...")
                        time.sleep(sleep_seconds)
                        continue
                break
            except Exception as e:
                logging.exception(f"Unexpected error calling Gemini API with model '{current_model}' (attempt {attempt}/{MAX_RETRIES_PER_MODEL})")
                last_error_response = (jsonify({
                    "status": "error",
                    "message": f"Server error on model '{current_model}': {str(e)}"
                }), 500)
                if attempt < MAX_RETRIES_PER_MODEL:
                    sleep_seconds = calculate_backoff(attempt)
                    if time.time() - start_time + sleep_seconds < MAX_TOTAL_REQUEST_TIMEOUT - 2:
                        logging.warning(f"Backing off (full jitter) for {sleep_seconds:.2f}s before attempt {attempt + 1}/{MAX_RETRIES_PER_MODEL}...")
                        time.sleep(sleep_seconds)
                        continue
                break

        # Check budget before proceeding to next model in hierarchy
        if time.time() - start_time >= MAX_TOTAL_REQUEST_TIMEOUT - 3:
            logging.warning(f"Stopping model tier fallback due to time budget exhaustion ({time.time() - start_time:.1f}s elapsed).")
            break

        # Log fallback attempt if there is a next model in the tier list
        if idx < len(models_to_try) - 1:
            next_model = models_to_try[idx + 1]
            logging.warning(f"Model '{current_model}' exhausted. Cascading fallback to next model tier '{next_model}'...")

    if last_error_response:
        return last_error_response

    return jsonify({
        "status": "error",
        "message": f"Gemini API query failed or timed out after {time.time() - start_time:.1f}s across all model tiers."
    }), 503


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5050))
    app.run(host="0.0.0.0", port=port, debug=False)


