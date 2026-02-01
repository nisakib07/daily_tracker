import nextPWA from "next-pwa";

/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: { ignoreBuildErrors: true },
  images: { unoptimized: true },
  turbopack: {},
};

export default nextPWA({
  dest: "public",
  disable: process.env.NODE_ENV === "development",

  // 🔑 CRITICAL FIX
  runtimeCaching: [
    {
      urlPattern: ({ request }) => request.mode === "navigate",
      handler: "NetworkFirst",
      options: {
        cacheName: "pages",
        networkTimeoutSeconds: 10,
      },
    },
  ],

  register: true,
  skipWaiting: true,
  clientsClaim: true,

  // ❌ REMOVE offline fallback for now
  fallbacks: false,
})(nextConfig);
