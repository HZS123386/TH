FROM node:24-bookworm-slim AS node
FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    NODE_NO_WARNINGS=1

COPY --from=node /usr/local/bin/node /usr/local/bin/node
RUN apt-get update \
    && apt-get install -y --no-install-recommends libstdc++6 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/TH
COPY TH/backend/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY TH/backend ./backend
COPY TH/scripts ./scripts
COPY TH/src ./src
COPY TH/package.json ./package.json
COPY TH/node_modules/thai-astrology ./node_modules/thai-astrology
COPY ["western-astrology-h5 4/site", "/app/western-astrology-h5 4/site"]

RUN groupadd --gid 10001 astro \
    && useradd --uid 10001 --gid astro --no-create-home astro \
    && mkdir -p /app/TH/data \
    && chown astro:astro /app/TH/data
RUN python -c "from backend.app.thai_readings import copy_for, calculation_in_prose; assert copy_for('zh') and copy_for('th'); calculation_in_prose('先整理你当前最关注的问题', allow_practical_details=True)"
USER astro
EXPOSE 8000

HEALTHCHECK --interval=20s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"

CMD ["python", "-m", "uvicorn", "backend.app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
