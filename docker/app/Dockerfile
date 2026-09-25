FROM python:3.12-slim
RUN pip install --no-cache-dir flask psycopg2-binary
COPY app.py /app/app.py
EXPOSE 5000
CMD ["python", "/app/app.py"]
