import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import logging
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger("uvicorn.error")

def send_email(to_email: str, subject: str, body: str):
    """Sendet eine E-Mail über SMTP"""
    smtp_host = os.getenv("SMTP_HOST")
    smtp_port = int(os.getenv("SMTP_PORT", 587))
    smtp_user = os.getenv("SMTP_USER")
    smtp_password = os.getenv("SMTP_PASSWORD")
    print(smtp_user)
    print(smtp_host)

    if not all([smtp_host, smtp_user, smtp_password]):
        logger.warning("SMTP nicht konfiguriert - E-Mail wird nur geloggt")
        logger.info(f"E-Mail an {to_email}: {subject}")
        return

    msg = MIMEMultipart()
    msg['From'] = smtp_user
    msg['To'] = to_email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain'))

    try:
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            server.starttls()
            server.login(smtp_user, smtp_password)
            server.send_message(msg)
        logger.info(f"E-Mail erfolgreich an {to_email} gesendet")
    except Exception as e:
        logger.error(f"Fehler beim E-Mail-Versand: {e}")