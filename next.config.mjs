import nextPWA from "next-pwa";

/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
};

export default nextPWA({
  dest: "public",
  disable: process.env.NODE_ENV === "development",
})(nextConfig);
