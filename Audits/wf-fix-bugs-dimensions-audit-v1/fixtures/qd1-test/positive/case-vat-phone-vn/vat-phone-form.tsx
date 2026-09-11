// REQ-ID: MCV3-TEST (IMP-009 fixture — locale-aware form fill)
// React form với VN-specific HTML5 pattern attributes cho MST + phone + CCCD

import React, { useState } from 'react';

interface FormData {
  taxCode: string;
  phone: string;
  nationalId: string;
  postalCode: string;
}

export function VatPhoneForm() {
  const [data, setData] = useState<FormData>({ taxCode: '', phone: '', nationalId: '', postalCode: '' });
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Validate MST format (10 hoặc 13 chữ số)
    if (!/^\d{10}(-\d{3})?$/.test(data.taxCode)) {
      setError('Mã số thuế không hợp lệ (cần 10 hoặc 13 chữ số)');
      return;
    }
    // Validate phone VN
    if (!/^0[35789][0-9]{8}$/.test(data.phone)) {
      setError('Số điện thoại không hợp lệ (định dạng 0[35789]xxxxxxxx)');
      return;
    }
    setError('');
    setSubmitted(true);
  };

  if (submitted) {
    return <div className="success">Đăng ký thành công! MST: {data.taxCode}</div>;
  }

  return (
    <form onSubmit={handleSubmit} id="vat-phone-form">
      <h2>Đăng ký thông tin doanh nghiệp</h2>

      {error && <div className="error">{error}</div>}

      <div className="field">
        <label htmlFor="tax-code">Mã số thuế (MST)</label>
        <input
          id="tax-code"
          name="taxCode"
          type="text"
          pattern="\d{10}(-\d{3})?"
          placeholder="Nhập MST 10 hoặc 13 chữ số"
          value={data.taxCode}
          onChange={e => setData({ ...data, taxCode: e.target.value })}
          required
          title="Mã số thuế gồm 10 chữ số (0123456789) hoặc 13 chữ số có chi nhánh (0123456789-001)"
        />
      </div>

      <div className="field">
        <label htmlFor="phone">Số điện thoại (SĐT)</label>
        <input
          id="phone"
          name="phone"
          type="tel"
          pattern="0[35789][0-9]{8}"
          placeholder="Nhập SĐT 10 chữ số (VD: 0912345678)"
          value={data.phone}
          onChange={e => setData({ ...data, phone: e.target.value })}
          required
          title="Số điện thoại di động Việt Nam 10 chữ số (đầu số 03x, 05x, 07x, 08x, 09x)"
        />
      </div>

      <div className="field">
        <label htmlFor="national-id">Số CCCD / CMND</label>
        <input
          id="national-id"
          name="nationalId"
          type="text"
          pattern="[0-9]{9}|[0-9]{12}"
          placeholder="Nhập số CCCD 12 chữ số hoặc CMND 9 chữ số"
          value={data.nationalId}
          onChange={e => setData({ ...data, nationalId: e.target.value })}
          required
          title="Căn cước công dân (12 số) hoặc Chứng minh nhân dân (9 số)"
        />
      </div>

      <div className="field">
        <label htmlFor="postal-code">Mã bưu điện</label>
        <input
          id="postal-code"
          name="postalCode"
          type="text"
          pattern="\d{6}"
          placeholder="VD: 700000"
          value={data.postalCode}
          onChange={e => setData({ ...data, postalCode: e.target.value })}
          title="Mã bưu điện 6 chữ số"
        />
      </div>

      <button type="submit">Xác nhận đăng ký</button>
    </form>
  );
}
