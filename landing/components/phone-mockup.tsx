export function PhoneMockup({
  src,
  alt,
  className = "",
}: {
  src: string;
  alt: string;
  className?: string;
}) {
  return (
    <div
      className={`relative w-[300px] h-[612px] md:w-[400px] md:h-[816px] shrink-0 ${className}`}
    >
      {/* The Screenshot */}
      <div className="absolute inset-[14px] md:inset-[18px] rounded-[36px] md:rounded-[48px] overflow-hidden bg-black border-4 border-black">
        <img
          src={src}
          alt={alt}
          className="w-full h-full object-cover"
          loading="lazy"
        />
      </div>
      {/* The Bezel Overlay */}
      <img
        src="/app-screenshots/iphone_bezels_16_pro.png"
        alt="iPhone Bezel"
        className="absolute inset-0 w-full h-full object-contain pointer-events-none z-10 drop-shadow-2xl"
      />
    </div>
  );
}
