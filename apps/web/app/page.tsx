import { MarketingHome } from "@/components/MarketingHome";
import { AuthRedirect } from "@/components/AuthRedirect";

export default function Home() {
  return (
    <AuthRedirect>
      <MarketingHome />
    </AuthRedirect>
  );
}
