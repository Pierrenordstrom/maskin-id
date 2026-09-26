/**
 * Ordmärket – ritas aldrig om, filerna kommer direkt ur MaskinID.eps (public/logo).
 * Primärt på ljus botten, negativt på mörk. Minsta bredd 100 px på skärm.
 */
export function Wordmark({ height = 22, variant = "auto" }: { height?: number; variant?: "auto" | "ljus" | "negativ" }) {
  const width = Math.round((height * 1481.361) / 217.435);
  if (variant === "ljus") return <img src="/logo/maskinid-ordmarke.svg" alt="MaskinID" height={height} width={width} />;
  if (variant === "negativ") return <img src="/logo/maskinid-ordmarke-negativ.svg" alt="MaskinID" height={height} width={width} />;
  return (
    <>
      <img className="logo-ljust" src="/logo/maskinid-ordmarke.svg" alt="MaskinID" height={height} width={width} />
      <img className="logo-morkt" src="/logo/maskinid-ordmarke-negativ.svg" alt="MaskinID" height={height} width={width} />
    </>
  );
}
