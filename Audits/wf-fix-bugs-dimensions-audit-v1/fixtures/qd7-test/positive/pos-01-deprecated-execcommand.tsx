// QD7 Fixture pos-01 — positive case (HIGH signal expected)
// Demonstrates: browser clipboard operation using legacy DOM execCommand approach

export function copyToClipboard(text: string): void {
  const el = document.createElement('textarea');
  el.value = text;
  el.setAttribute('readonly', '');
  el.style.position = 'absolute';
  el.style.left = '-9999px';
  document.body.appendChild(el);
  el.select();
  document.execCommand('copy');
  document.body.removeChild(el);
}
