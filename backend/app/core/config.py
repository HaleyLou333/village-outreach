from pydantic import BaseSettings

class Settings(BaseSettings):
    app_name: str = "CCVO Backend"
    environment: str = "development"

    class Config:
        env_file = ".env"

settings = Settings()