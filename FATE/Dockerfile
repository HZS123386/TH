FROM node:22-bookworm-slim AS web
WORKDIR /build
COPY h5/package*.json ./
RUN npm ci
COPY h5/ ./
RUN npm run build

FROM python:3.13-slim
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
WORKDIR /opt/fate
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt && useradd --system --uid 10001 fate
COPY backend/ ./backend/
COPY --from=web /build/dist ./h5/dist
USER fate
WORKDIR /opt/fate/backend
CMD ["uvicorn", "fate.main:app", "--host", "0.0.0.0", "--port", "8710", "--no-access-log"]
