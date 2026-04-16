import Link from "next/link";
import Image from "next/image";

const features = [
  "Dynamic income and expense categories",
  "Realtime web and app database sync",
  "Member collection and dues tracking",
  "Prayer times, announcements, and documents",
  "Role-based mosque admin access",
  "Vercel web deploy with Firebase backend"
];

export function MarketingHome() {
  return (
    <main>
      <section className="hero-photo min-h-[92vh] text-white">
        <nav className="section flex items-center justify-between py-5">
          <Link href="/" className="text-xl font-black tracking-normal">
            Masjid<span className="text-[#d7bd72]">Manager</span>
          </Link>
          <div className="flex items-center gap-3">
            <Link href="/auth" className="btn-secondary border-white/25 bg-white/10 text-white">
              Login
            </Link>
            <Link href="/auth?mode=register" className="btn-primary bg-[#d0ad55] text-[#12231f]">
              Start SaaS
            </Link>
          </div>
        </nav>

        <div className="section grid min-h-[72vh] items-center py-14">
          <div className="max-w-3xl">
            <p className="mb-4 inline-flex border border-white/20 bg-white/10 px-3 py-2 text-sm font-bold">
              Amanah-first mosque operations, accounts, and community updates
            </p>
            <h1 className="max-w-3xl text-4xl font-black leading-tight tracking-normal sm:text-6xl">
              Manage every masjid with verified admins and clear accounts.
            </h1>
            <p className="mt-5 max-w-2xl text-lg leading-8 text-white/86">
              Track Zakat, donations, expenses, members, prayer times, documents, and
              announcements from the web dashboard while Firebase keeps every trusted device in
              sync.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link href="/auth?mode=register" className="btn-primary bg-white text-[#12322b]">
                Create mosque account
              </Link>
              <Link href="/dashboard" className="btn-secondary border-white/30 bg-white/10 text-white">
                Open dashboard
              </Link>
            </div>
          </div>
        </div>
      </section>

      <section className="section py-16">
        <div className="grid gap-5 md:grid-cols-3">
          {[
            ["Realtime", "Firestore listeners keep web and mobile views updated without refresh."],
            ["Flexible", "Admins can create Zakat, Fitra, building fund, bill, or any custom category."],
            ["Transparent", "Reports, receipts, and member dues help committees explain every taka."]
          ].map(([title, body]) => (
            <article className="card p-6" key={title}>
              <h2 className="text-xl font-black">{title}</h2>
              <p className="mt-3 leading-7 text-[var(--muted)]">{body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="bg-white py-16">
        <div className="section grid gap-10 lg:grid-cols-[1fr_420px] lg:items-center">
          <div>
            <p className="text-sm font-black uppercase text-[var(--brand)]">MVP modules</p>
            <h2 className="mt-3 text-3xl font-black tracking-normal sm:text-4xl">
              Built for committee work, not just pretty screenshots.
            </h2>
            <div className="mt-8 grid gap-3 sm:grid-cols-2">
              {features.map((feature) => (
                <div className="flex items-start gap-3 border border-[var(--line)] p-4" key={feature}>
                  <span className="mt-1 h-2 w-2 bg-[var(--brand)]" />
                  <span className="font-semibold text-[var(--ink)]">{feature}</span>
                </div>
              ))}
            </div>
          </div>
          <Image
            src="https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=900&q=85"
            alt="Mosque interior with worshippers"
            width={900}
            height={1000}
            className="h-[460px] w-full object-cover"
          />
        </div>
      </section>

      <section className="section py-16">
        <div className="card grid gap-8 p-8 md:grid-cols-[1fr_auto] md:items-center">
          <div>
            <p className="text-sm font-black text-[var(--brand)]">Deployment ready</p>
            <h2 className="mt-2 text-3xl font-black">Vercel for web. Firebase for everything shared.</h2>
            <p className="mt-3 max-w-2xl leading-7 text-[var(--muted)]">
              Set Vercel root directory to <strong>apps/web</strong>, add Firebase environment
              variables, then both the web dashboard and Flutter app use the same Firestore data.
            </p>
          </div>
          <Link href="/auth?mode=register" className="btn-primary">
            Start setup
          </Link>
        </div>
      </section>
    </main>
  );
}
