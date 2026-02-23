import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET(): Promise<NextResponse> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    return NextResponse.json({ count: 0 });
  }

  try {
    const supabase = createClient(url, serviceKey);
    const { count, error } = await supabase
      .from("waitlist_subscribers")
      .select("id", { count: "exact", head: true })
      .is("unsubscribed_at", null);

    if (error) {
      console.error("waitlist-count error:", error.message);
      return NextResponse.json({ count: 0 });
    }

    return NextResponse.json(
      { count: count ?? 0 },
      { headers: { "Cache-Control": "no-store, max-age=0" } },
    );
  } catch (err) {
    console.error("waitlist-count error:", err);
    return NextResponse.json({ count: 0 });
  }
}
