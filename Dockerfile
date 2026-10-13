# Tonos in a container, for those who would rather not install Python:
#   docker run -p 8765:8765 ghcr.io/joaquinmuzzi/tonos
# then open http://127.0.0.1:8765. The models are inside the image, so it works offline.
# Analyses are kept in the /data volume (see docker-compose.yml).

# python:3.12-slim (Debian 13); Dependabot keeps the digest up to date
FROM python:3.12-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS base

# ---------------------------------------------------------------- build: the environment and the models
FROM base AS build

# git, for the two dependencies installed from their repositories
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=/opt/venv/bin:$PATH \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TORCH_HOME=/opt/models
RUN python -m venv /opt/venv

# The same pinned versions as install.ps1 and install.sh
COPY requirements.txt constraints.txt /src/
RUN pip install torch==2.7.1 torchaudio==2.7.1 --index-url https://download.pytorch.org/whl/cpu \
    && pip install -r /src/requirements.txt -c /src/constraints.txt \
    && pip install --no-deps \
        "consonance-ace @ git+https://github.com/andreamust/consonance-ACE@d17633aea4e68e616e735d09df97b97ae3428e71" \
    # Not needed to run the app: the test runner, the libraries' own test suites (except numpy's,
    # which numpy imports), the C++ headers of PyTorch and pip itself
    && find /opt/venv -path "*/site-packages/numpy" -prune -o -type d -name tests -prune -exec rm -rf {} + \
    && rm -rf /opt/venv/lib/python3.12/site-packages/torch/include \
    && pip uninstall -y pytest pip

# Download the beat model into /opt/models and check that the three models load
COPY tonos /src/tonos
RUN cd /src && python -m tonos --preload

# ---------------------------------------------------------------- the image that runs
FROM base

# ffmpeg reads the audio of every format the app accepts
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/venv /opt/venv
COPY --from=build /opt/models /opt/models
COPY tonos /app/tonos

RUN useradd --create-home --uid 1000 tonos \
    && mkdir /data \
    && chown tonos /data

ENV PATH=/opt/venv/bin:$PATH \
    TORCH_HOME=/opt/models \
    TONOS_DATA_DIR=/data \
    PYTHONUNBUFFERED=1
USER tonos
WORKDIR /app
VOLUME /data
EXPOSE 8765

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8765/', timeout=4)"]

# 0.0.0.0: inside the container, so that the published port reaches it
CMD ["python", "-m", "tonos", "--host", "0.0.0.0", "--no-browser"]
