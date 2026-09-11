# Fixture: SQLAlchemy models with ForeignKey columns missing index=True
# Expected signal: "SQLAlchemy: ForeignKey column thiếu index=True"
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


# IMP-010 fixture: Column với ForeignKey nhưng thiếu index=True
class Invoice(Base):
    __tablename__ = 'invoices'

    id = Column(Integer, primary_key=True)
    invoice_number = Column(String(50), unique=True, nullable=False)
    amount = Column(Integer, nullable=False)

    # ForeignKey without index=True — signal expected
    customer_id = Column(Integer, ForeignKey('customers.id'), nullable=False)
    # Missing: index=True

    order_id = Column(Integer, ForeignKey('orders.id'), nullable=True)
    # Missing: index=True

    customer = relationship('Customer', back_populates='invoices')


class Customer(Base):
    __tablename__ = 'customers'

    id = Column(Integer, primary_key=True)
    name = Column(String(200), nullable=False)
    email = Column(String(200), unique=True, nullable=False)

    invoices = relationship('Invoice', back_populates='customer')
