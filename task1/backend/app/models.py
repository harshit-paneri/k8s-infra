"""SQLAlchemy ORM models for Dodo Payments."""

from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, Enum
import enum

from app.database import Base


class TransactionStatus(str, enum.Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"


class Transaction(Base):
    """Represents a payment transaction."""

    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    transaction_id = Column(String(36), unique=True, nullable=False, index=True)
    customer_name = Column(String(255), nullable=False)
    customer_email = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    currency = Column(String(3), default="INR")
    status = Column(
        Enum(TransactionStatus),
        default=TransactionStatus.PENDING,
        nullable=False,
    )
    description = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
