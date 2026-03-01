"""
Dodo Payments Backend API
=========================
FastAPI application for managing payment transactions.
Includes health checks, Prometheus metrics, and structured logging.
"""

import uuid
import time
import structlog
from contextlib import asynccontextmanager
from typing import List

from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response

from app.config import settings
from app.database import engine, get_db, Base
from app.models import Transaction, TransactionStatus
from app.schemas import (
    TransactionCreate,
    TransactionResponse,
    HealthResponse,
    TransactionStats,
)

# ── Structured Logging ─────────────────────────────────────────────
structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
)
logger = structlog.get_logger()

# ── Prometheus Metrics ──────────────────────────────────────────────
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
)
TRANSACTION_COUNT = Counter(
    "transactions_total",
    "Total transactions processed",
    ["status"],
)


# ── Application Lifecycle ──────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create database tables on startup."""
    logger.info("starting_application", version=settings.APP_VERSION)
    Base.metadata.create_all(bind=engine)
    logger.info("database_tables_created")
    yield
    logger.info("shutting_down_application")


app = FastAPI(
    title="Dodo Payments API",
    description="Payment transaction management API for Dodo Payments",
    version=settings.APP_VERSION,
    lifespan=lifespan,
)

# ── CORS Middleware ─────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Metrics Middleware ──────────────────────────────────────────────
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Record request count and latency for Prometheus."""
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time

    endpoint = request.url.path
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=endpoint,
        status=response.status_code,
    ).inc()
    REQUEST_LATENCY.labels(
        method=request.method,
        endpoint=endpoint,
    ).observe(duration)

    return response


# ── Health Endpoints ────────────────────────────────────────────────
@app.get("/api/health", response_model=HealthResponse, tags=["Health"])
def health_check(db: Session = Depends(get_db)):
    """Health check endpoint for Kubernetes probes."""
    try:
        db.execute("SELECT 1")
        db_status = "connected"
    except Exception:
        db_status = "disconnected"

    return HealthResponse(
        status="healthy",
        version=settings.APP_VERSION,
        environment=settings.ENVIRONMENT,
        database=db_status,
    )


@app.get("/api/ready", tags=["Health"])
def readiness_check(db: Session = Depends(get_db)):
    """Readiness probe — checks database connectivity."""
    try:
        db.execute("SELECT 1")
        return {"status": "ready"}
    except Exception as e:
        logger.error("readiness_check_failed", error=str(e))
        raise HTTPException(status_code=503, detail="Database not ready")


# ── Prometheus Metrics Endpoint ─────────────────────────────────────
@app.get("/metrics", tags=["Monitoring"])
def metrics():
    """Expose Prometheus metrics."""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )


# ── Transaction Endpoints ──────────────────────────────────────────
@app.get("/api/transactions", response_model=List[TransactionResponse], tags=["Transactions"])
def list_transactions(
    skip: int = 0,
    limit: int = 50,
    status: str = None,
    db: Session = Depends(get_db),
):
    """List all transactions with optional filtering."""
    query = db.query(Transaction)
    if status:
        query = query.filter(Transaction.status == status)
    transactions = query.order_by(Transaction.created_at.desc()).offset(skip).limit(limit).all()
    logger.info("transactions_listed", count=len(transactions))
    return transactions


@app.get("/api/transactions/{transaction_id}", response_model=TransactionResponse, tags=["Transactions"])
def get_transaction(transaction_id: str, db: Session = Depends(get_db)):
    """Get a specific transaction by ID."""
    txn = db.query(Transaction).filter(Transaction.transaction_id == transaction_id).first()
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return txn


@app.post("/api/transactions", response_model=TransactionResponse, status_code=201, tags=["Transactions"])
def create_transaction(txn_data: TransactionCreate, db: Session = Depends(get_db)):
    """Create a new payment transaction."""
    txn = Transaction(
        transaction_id=str(uuid.uuid4()),
        customer_name=txn_data.customer_name,
        customer_email=txn_data.customer_email,
        amount=txn_data.amount,
        currency=txn_data.currency,
        description=txn_data.description,
        status=TransactionStatus.COMPLETED,
    )
    db.add(txn)
    db.commit()
    db.refresh(txn)

    TRANSACTION_COUNT.labels(status=txn.status.value).inc()
    logger.info(
        "transaction_created",
        transaction_id=txn.transaction_id,
        amount=txn.amount,
        currency=txn.currency,
    )
    return txn


@app.get("/api/transactions/stats/summary", response_model=TransactionStats, tags=["Transactions"])
def transaction_stats(db: Session = Depends(get_db)):
    """Get aggregated transaction statistics."""
    total = db.query(func.count(Transaction.id)).scalar() or 0
    total_amount = db.query(func.sum(Transaction.amount)).scalar() or 0
    completed = db.query(func.count(Transaction.id)).filter(
        Transaction.status == TransactionStatus.COMPLETED
    ).scalar() or 0
    failed = db.query(func.count(Transaction.id)).filter(
        Transaction.status == TransactionStatus.FAILED
    ).scalar() or 0
    pending = db.query(func.count(Transaction.id)).filter(
        Transaction.status == TransactionStatus.PENDING
    ).scalar() or 0

    return TransactionStats(
        total_transactions=total,
        total_amount=total_amount,
        completed_count=completed,
        failed_count=failed,
        pending_count=pending,
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)
