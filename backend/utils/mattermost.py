# libre-stage - Band rehearsal and gig management software
# Copyright (C) 2026  libre-stage contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import requests
from typing import Optional
from dotenv import load_dotenv
import os
import logging

logger = logging.getLogger("uvicorn.error")
load_dotenv()

"""
Mattermost notification utility.

Sends messages to a Mattermost channel via an *Incoming Webhook* URL.
The webhook URL is read from the ``MATTERMOST_WEBHOOK_URL`` environment
variable by default but can be overridden per call.
"""

def send_mm_message(
        text: str,
        webhook = os.getenv("MATTERMOST_WEBHOOK_URL"),
        channel: Optional[str] = None
) -> bool:
    """
    Send a message to a Mattermost channel via an Incoming Webhook.

    Args:
        text (str): The message text to send (Markdown supported).
        webhook (str): Webhook URL. Defaults to the
            ``MATTERMOST_WEBHOOK_URL`` environment variable.
        channel (str | None): Optional channel override. If ``None``
            the webhook's default channel is used.

    Returns:
        bool: ``True`` on success.

    Raises:
        ValueError: If *webhook* is empty/``None`` or *text* is ``None``.
        TypeError: If *text* or *channel* are not strings.
        requests.exceptions.HTTPError: If the Mattermost server returns
            a non-2xx status code.
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
