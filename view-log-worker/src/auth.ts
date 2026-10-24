// 共有シークレットによる呼び出し元認可。
// タイミング攻撃を避けるため定数時間比較を行う。
export function isAuthorized(request: Request, secret: string | undefined): boolean {
  if (!secret) return false; // 未設定は認証不能＝拒否（事故防止）
  const provided = request.headers.get("X-Ingest-Secret") ?? "";
  return timingSafeEqual(provided, secret);
}

function timingSafeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const aBytes = encoder.encode(a);
  const bBytes = encoder.encode(b);
  // 長さが異なっても早期 return せず、比較長を固定して情報を漏らさない
  const length = Math.max(aBytes.length, bBytes.length);
  let mismatch = aBytes.length ^ bBytes.length;
  for (let i = 0; i < length; i++) {
    mismatch |= (aBytes[i] ?? 0) ^ (bBytes[i] ?? 0);
  }
  return mismatch === 0;
}
