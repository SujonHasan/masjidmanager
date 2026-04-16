import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/**/*.{js,ts,jsx,tsx,mdx}"
  ],
  theme: {
    extend: {
      colors: {
        ink: "#17211f",
        moss: "#0f6f5c",
        emeraldBrand: "#13896f",
        goldSoft: "#c7a450",
        paper: "#f7faf8"
      },
      boxShadow: {
        soft: "0 18px 50px rgba(19, 137, 111, 0.12)",
        card: "0 10px 30px rgba(23, 33, 31, 0.08)"
      }
    }
  },
  plugins: []
};

export default config;
