import type {NextConfig} from 'next';

const nextConfig: NextConfig = {
    reactStrictMode: true,
    trailingSlash: true,
    output: 'standalone',
    distDir: '.next',
    basePath: "/test"
};

export default nextConfig;
