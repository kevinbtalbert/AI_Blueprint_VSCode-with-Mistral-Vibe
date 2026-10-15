# Cloudera ML runtime: VS Code (code-server) + Mistral Vibe CLI and VS Code extension
FROM --platform=linux/amd64 docker.repository.cloudera.com/cloudera/cdsw/ml-runtime-pbj-workbench-python3.13-standard:2026.08.1-b5

USER root

# ── System dependencies ─────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        vim nano curl wget less tree jq unzip zip git ca-certificates \
        ripgrep fd-find bat netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

# ── code-server (browser VS Code) ───────────────────────────────────────────
# Pattern from https://github.com/cloudera/community-ml-runtimes/tree/main/vscode
ARG CODE_SERVER_VERSION=4.141.0
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version "${CODE_SERVER_VERSION}"

COPY scripts/vscode-launch.sh /usr/local/bin/vscode
COPY scripts/configure-vibe-from-env.sh /usr/local/bin/configure-vibe-from-env
COPY scripts/link-vibe-cli.sh /usr/local/bin/link-vibe-cli
COPY scripts/install-mistral-vibe-cli.sh /usr/local/bin/install-mistral-vibe-cli
COPY scripts/mistral-vibe-shell.sh /etc/profile.d/mistral-vibe.sh

RUN chmod +x /usr/local/bin/vscode /usr/local/bin/configure-vibe-from-env \
      /usr/local/bin/link-vibe-cli /usr/local/bin/install-mistral-vibe-cli && \
    ln -sf /usr/local/bin/vscode /usr/local/bin/ml-runtime-editor && \
    /usr/local/bin/install-mistral-vibe-cli && \
    grep -q 'mistral-vibe.sh' /home/cdsw/.bashrc 2>/dev/null || \
      printf '%s\n' '[ -f /etc/profile.d/mistral-vibe.sh ] && . /etc/profile.d/mistral-vibe.sh' >> /home/cdsw/.bashrc && \
    chown cdsw:cdsw /home/cdsw/.bashrc && \
    mkdir -p /home/cdsw/.local/share/code-server/User && \
    chown -R cdsw:cdsw /home/cdsw/.local

ENV PATH="/usr/local/bin:${PATH}"

ENV CODE_SERVER_BIND="127.0.0.1:8090"

ENV ML_RUNTIME_EDITION="VS Code + Mistral Vibe" \
    ML_RUNTIME_EDITOR="VsCode" \
    ML_RUNTIME_KERNEL="Python 3.13" \
    ML_RUNTIME_SHORT_VERSION="1.1" \
    ML_RUNTIME_MAINTENANCE_VERSION="1" \
    ML_RUNTIME_DESCRIPTION="Browser VS Code with Mistral Vibe CLI and extension"

ENV ML_RUNTIME_FULL_VERSION="${ML_RUNTIME_SHORT_VERSION}.${ML_RUNTIME_MAINTENANCE_VERSION}"

LABEL com.cloudera.ml.runtime.edition=$ML_RUNTIME_EDITION \
      com.cloudera.ml.runtime.full-version=$ML_RUNTIME_FULL_VERSION \
      com.cloudera.ml.runtime.short-version=$ML_RUNTIME_SHORT_VERSION \
      com.cloudera.ml.runtime.maintenance-version=$ML_RUNTIME_MAINTENANCE_VERSION \
      com.cloudera.ml.runtime.description=$ML_RUNTIME_DESCRIPTION \
      com.cloudera.ml.runtime.editor=$ML_RUNTIME_EDITOR

WORKDIR /home/cdsw
USER cdsw

# ── Mistral Vibe VS Code extension (Visual Studio Marketplace) ────────────────
# https://marketplace.visualstudio.com/items?itemName=mistralai.mistral-vibe-code
ARG MISTRAL_VIBE_EXTENSION_VERSION=1.23.161
RUN set -eux; \
    vsix_url="$(curl -fsSL "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json;api-version=7.1-preview.1" \
      -d "{\"filters\":[{\"criteria\":[{\"filterType\":7,\"value\":\"mistralai.mistral-vibe-code\"}],\"pageNumber\":1,\"pageSize\":1}],\"assetTypes\":[\"Microsoft.VisualStudio.Services.VSIXPackage\"],\"flags\":131}" \
      | jq -r --arg ver "${MISTRAL_VIBE_EXTENSION_VERSION}" \
          '.results[0].extensions[0].versions[] | select(.version==$ver) | .files[] | select(.assetType=="Microsoft.VisualStudio.Services.VSIXPackage") | .source' \
      | head -1)"; \
    test -n "${vsix_url}"; \
    curl -fsSL "${vsix_url}" -o /tmp/mistral-vibe-code.vsix; \
    code-server --install-extension /tmp/mistral-vibe-code.vsix; \
    rm -f /tmp/mistral-vibe-code.vsix

# Recommend the extension; credentials are injected from project env at runtime.
RUN printf '%s\n' \
      '{' \
      '  "extensions.recommendations": ["mistralai.mistral-vibe-code"]' \
      '}' \
      > /home/cdsw/.local/share/code-server/User/settings.json
