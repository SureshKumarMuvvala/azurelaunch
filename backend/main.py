from fastapi import FastAPI
import os

app = FastAPI(title="AzureLaunch API")

VERSION = os.getenv("APP_VERSION", "1.0.0")


@app.get("/")
def root():
    return {"message": "Hello to my world! 👋"}


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/version")
def version():
    return {"version": VERSION, "service": "azurelaunch-backend"}
