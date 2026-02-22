from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(
    title="Validatyr API",
    description="AI Idea Validator Backend",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from api.routes import router as validation_router
app.include_router(validation_router, prefix="/api/v1")

@app.get("/")
def read_root():
    return {"message": "Validatyr API is running"}

@app.get("/health")
def health_check():
    return {"status": "ok"}
