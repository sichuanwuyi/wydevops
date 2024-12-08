import type {NextConfig} from 'next';

const nextConfig: NextConfig = {
    output: "standalone",
    reactStrictMode: true,
    trailingSlash: true,
    //distDir: '.next',
    //通过basePath参数添加项目前缀，用于网关将项目流量正确导流到后端服务。
    //特殊地，所有Image组件的src属性值需要手动添加basePath参数前缀，示例见：app/page.tsx文件中的Image。
    basePath: "/test"
};

export default nextConfig;
