"""Pydantic schemas for request/response validation."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field


class TransactionCreate(BaseModel):
    """Schema for creating a new transaction."""

    customer_name: str = Field(..., min_length=1, max_length=255)
    customer_email: str = Field(..., max_length=255)
    amount: float = Field(..., gt=0)
    currency: str = Field(default="INR", max_length=3)
    description: Optional[str] = Field(None, max_length=500)


class TransactionResponse(BaseModel):
    """Schema for transaction API responses."""

    id: int
    transaction_id: str
    customer_name: str
    customer_email: str
    amount: float
    currency: str
    status: str
    description: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


class HealthResponse(BaseModel):
    """Schema for health check response."""

    status: str
    version: str
    environment: str
    database: str


class TransactionStats(BaseModel):
    """Aggregated transaction statistics."""

    total_transactions: int
    total_amount: float
    completed_count: int
    failed_count: int
    pending_count: int
