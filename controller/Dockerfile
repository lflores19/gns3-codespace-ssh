FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir ryu eventlet==0.30.2
COPY sd_policies.py /app/sd_policies.py
COPY simple_switch_13.py /app/simple_switch_13.py
EXPOSE 6653
CMD ["ryu-manager", "--ofp-tcp-listen-port", "6653", "/app/simple_switch_13.py", "/app/sd_policies.py"]
