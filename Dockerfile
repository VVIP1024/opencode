# 多阶段构建：使用 CI 中的 bun-node 镜像作为构建环境  
# 参考：packages/containers/README.md 与 packages/containers/script/build.ts  
ARG REGISTRY=ghcr.io/anomalyco  
ARG TAG=24.04  
FROM ${REGISTRY}/build/bun-node:${TAG} AS builder  
  
WORKDIR /src  

# 复制依赖清单、工作区与补丁
# 复制整个工作区结构（确保 packages/sdk/js 和 packages/slack 存在）  
COPY packages packages  
# 复制依赖清单（使用 bun.lock 而非 bun.lockb）  
COPY package.json bun.lock ./  
COPY patches patches
# 安装依赖（使用 frozen-lockfile 确保可复现）  
RUN bun install --frozen-lockfile 
  
# 复制源码  
COPY . .  
  
# 构建 CLI 二进制（参考 packages/opencode/script/build.ts）（仅构建当前平台，避免跨平台依赖解析错误）（跳过构建时的跨平台依赖安装）  
RUN cd packages/opencode && bun run ./script/build.ts --single --skip-install  
  
# 运行时镜像：使用更小的基础镜像（例如 ubuntu:24.04 或 alpine）  
FROM ubuntu:24.04 AS runtime  
  
# 安装运行时依赖（ripgrep 是 OpenCode 运行时需要）  
RUN apt-get update && apt-get install -y --no-install-recommends \
    ripgrep \
    ca-certificates \
    curl \
    bash \
 && rm -rf /var/lib/apt/lists/*

# 拷贝 Bun 运行环境
COPY --from=builder /root/.bun /root/.bun
ENV PATH="/root/.bun/bin:${PATH}"

# 复制构建产物（使用与构建脚本输出匹配的路径）  
COPY --from=builder /src/packages/opencode/dist/opencode-*/bin/opencode /usr/local/bin/opencode  

# 设置入口点  
ENTRYPOINT ["opencode"]
