from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI(title="AzureLaunch API")

VERSION = os.getenv("APP_VERSION", "1.0.0")

# Allow requests from the frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://azurelaunch-frontend.kindriver-e93cab17.eastus.azurecontainerapps.io",
        "http://localhost:8080",   # local dev
        "http://localhost:3000",   # local dev alternate
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {"message": "Hello to my world! 👋"}


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/version")
def version():
    return {"version": VERSION, "service": "azurelaunch-backend"}