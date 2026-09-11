// IMP-002 fixture: Vietnamese CTA elements for locale-aware CTA probe
// Tests that wf-fix-probe-static-cta.sh detects VI-locale CTAs

import React from 'react';

interface Product {
  id: number;
  name: string;
  price: number;
}

export function ProductPage({ product }: { product: Product }) {
  return (
    <div className="product-page">
      <h1>{product.name}</h1>
      <p className="price">{product.price.toLocaleString('vi-VN')} đ</p>

      {/* Purchase CTAs - should be detected as vi CTA signals */}
      <button className="btn-primary" onClick={() => addToCart(product)}>
        Thêm vào giỏ
      </button>

      <button className="btn-buy" onClick={() => buyNow(product)}>
        Mua ngay
      </button>

      <button className="btn-order" onClick={() => placeOrder(product)}>
        Đặt hàng
      </button>

      {/* Discovery CTAs */}
      <a href={`/products/${product.id}`} className="btn-secondary">
        Xem thêm
      </a>

      <a href="/products" className="btn-link">
        Tìm hiểu thêm
      </a>

      {/* Registration CTAs */}
      <div className="auth-section">
        <button className="btn-register" onClick={handleRegister}>
          Đăng ký
        </button>
        <button className="btn-login" onClick={handleLogin}>
          Đăng nhập
        </button>
      </div>

      {/* Contact CTA */}
      <a href="/contact" className="btn-contact">
        Liên hệ
      </a>

      {/* Checkout */}
      <button className="btn-checkout" onClick={handleCheckout}>
        Thanh toán
      </button>
    </div>
  );
}

function addToCart(p: Product) { console.log('add', p.id); }
function buyNow(p: Product) { console.log('buy', p.id); }
function placeOrder(p: Product) { console.log('order', p.id); }
function handleRegister() { console.log('register'); }
function handleLogin() { console.log('login'); }
function handleCheckout() { console.log('checkout'); }
