#!/usr/bin/env python3
import sys
import time
import xml.etree.ElementTree as ET
import requests
from requests.auth import HTTPDigestAuth

# Device Configuration
CAMERA_IP = "192.168.50.75"
CAMERA_USER = "admin"
CAMERA_PASS = "4Real4Rea!"
STREAM_URL = f"http://{CAMERA_IP}/ISAPI/Event/notification/alertStream"

def handle_active_event(event_type, channel_id, timestamp, raw_xml):
    """
    Hook called whenever an event state is 'active'.
    Add notifications, MQTT publishes, shell commands, or logging here.
    """
    print(f"\n[ALERT TRIGGERED] Event: {event_type} | Channel: {channel_id} | Time: {timestamp}")
    
    # Example action routing:
    if event_type == "VMD":
        print("  -> Motion detected! Triggering recording / webhook...")
    elif event_type == "linedetection":
        print("  -> Line crossed!")
    elif event_type == "videoloss":
        print("  -> WARNING: Video loss detected on camera!")


def process_xml_block(xml_text):
    """Parses a complete XML event chunk and triggers actions on active states."""
    try:
        root = ET.fromstring(xml_text)
        
        # Remove XML namespace prefix if present
        tag_prefix = ""
        if root.tag.startswith("{"):
            tag_prefix = root.tag.split("}")[0] + "}"

        event_type = root.findtext(f"{tag_prefix}eventType", default="unknown")
        event_state = root.findtext(f"{tag_prefix}eventState", default="unknown").lower()
        channel_id = root.findtext(f"{tag_prefix}channelID", default="0")
        timestamp = root.findtext(f"{tag_prefix}dateTime", default="")

        if event_state == "active":
            handle_active_event(event_type, channel_id, timestamp, xml_text)
        else:
            # Heartbeats / inactive keep-alives (e.g., videoloss: inactive)
            sys.stdout.write(f"\r[Heartbeat] Device active | Last check: {timestamp} | Type: {event_type}")
            sys.stdout.flush()

    except ET.ParseError:
        # Partial chunks or boundary artifacts
        pass


def run_stream():
    """Main loop: connects via Digest auth and processes multipart chunks."""
    auth = HTTPDigestAuth(CAMERA_USER, CAMERA_PASS)
    buffer = ""

    while True:
        try:
            print(f"Connecting to {STREAM_URL} ...")
            with requests.get(STREAM_URL, auth=auth, stream=True, timeout=(10, 60)) as response:
                if response.status_code != 200:
                    print(f"Failed to connect: HTTP {response.status_code}")
                    time.sleep(5)
                    continue

                print("Connected! Listening for events...")
                for chunk in response.iter_lines(decode_unicode=True):
                    if chunk:
                        buffer += chunk + "\n"
                        
                        # Once a complete XML block boundary is collected
                        if "</EventNotificationAlert>" in buffer:
                            start_idx = buffer.find("<EventNotificationAlert")
                            end_idx = buffer.find("</EventNotificationAlert>") + len("</EventNotificationAlert>")
                            
                            if start_idx != -1 and end_idx != -1:
                                xml_content = buffer[start_idx:end_idx]
                                process_xml_block(xml_content)
                                buffer = buffer[end_idx:]

        except (requests.exceptions.RequestException, requests.exceptions.ConnectionError) as e:
            print(f"\nConnection dropped ({e}). Reconnecting in 5 seconds...")
            buffer = ""
            time.sleep(5)
        except KeyboardInterrupt:
            print("\nShutting down listener.")
            break


if __name__ == "__main__":
    run_stream()
