# REQ-ID: REQ-API-003
# FEAT-ID: FEAT-DEMO-ROUTE-003
# Fixture for IMP-001: FastAPI + Django route detection
# Tests: @app.get, @router.get, Django urlpatterns path()

from fastapi import FastAPI, APIRouter

app = FastAPI()
router = APIRouter(prefix="/api/v1")

@app.get("/health")
async def health_check():
    return {"status": "ok"}

@router.get("/products")
async def list_products():
    return []

@router.post("/products")
async def create_product(body: dict):
    return body

@router.get("/products/{product_id}")
async def get_product(product_id: int):
    return {}

@router.put("/products/{product_id}")
async def update_product(product_id: int, body: dict):
    return body

@router.delete("/products/{product_id}")
async def delete_product(product_id: int):
    return {"deleted": True}

# --- Django-style urlpatterns (for Django fixture simulation) ---
# from django.urls import path
# urlpatterns = [
#     path('orders/', views.order_list, name='order-list'),
#     path('orders/<int:pk>/', views.order_detail, name='order-detail'),
# ]
