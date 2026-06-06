import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SECRET_KEY   = os.getenv("SECRET_KEY", "cambia-esto")
    DB_HOST      = os.getenv("DB_HOST", "localhost")
    DB_USER      = os.getenv("DB_USER", "pil_admin")
    DB_PASSWORD  = os.getenv("DB_PASSWORD", "")
    DB_NAME      = os.getenv("DB_NAME", "pil_andina")