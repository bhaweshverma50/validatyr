from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv
from contextlib import asynccontextmanager

load_dotenv()


@asynccontextmanager
async def lifespan(app):
    from services.research_scheduler import start_scheduler
    start_scheduler()
    yield
    from services.research_scheduler import shutdown_scheduler
    shutdown_scheduler()


app = FastAPI(
    title="Validatyr API",
    description="AI Idea Validator Backend",
    version="1.0.0",
    lifespan=lifespan,
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

from api.research_routes import router as research_router
app.include_router(research_router, prefix="/api/v1/research")

@app.get("/")
def read_root():
    return {"message": "Validatyr API is running"}

@app.get("/health")
def health_check():
    return {"status": "ok"}
