import requests
from typing import Optional
from dotenv import load_dotenv
import os
import logging

logger = logging.getLogger("uvicorn.error")
load_dotenv()

def send_mm_message(
        text: str,
        webhook = os.getenv("MATTERMOST_WEBHOOK_URL"),
        channel: Optional[str] = None
) -> bool:
    """
    Sends a message to a Mattermost channel via Incoming Webhook.

    Raises:
        ValueError: if webhook URL or text is invalid.
        TypeError: if data types are incorrect.
        requests.exceptions.RequestException: in case of http errors.
    """


    #  Input Validation
    if not webhook or not isinstance(webhook, str):
        raise ValueError("Eine gültige Webhook-URL ist zwingend erforderlich.")

    if text is None:
        raise ValueError("Nachrichtentext darf nicht None sein.")

    if not isinstance(text, str):
        raise TypeError(f"Text muss ein String sein, erhalten: {type(text)}")

    # Build Payload
    payload = {"text": text}

    # Channel ist optional bei Webhooks (nutzt Default des Hooks, wenn nicht gesetzt)
    if channel:
        if not isinstance(channel, str):
            raise TypeError(f"Channel muss ein String sein, erhalten: {type(channel)}")
        payload["channel"] = channel

    # Send request
    response = requests.post(webhook, json=payload, timeout=10)

    # Raise exception in case of http errors
    response.raise_for_status()

    logger.info(f"Mattermost-Message successfully sent to Channel {channel}.")

    return True
