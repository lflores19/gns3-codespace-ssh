FROM python:3.11-slim
RUN pip install --no-cache-dir ryu eventlet==0.30.2
COPY sd_policies.py /app/sd_policies.py
COPY simple_switch_13.py /app/simple_switch_13.py
EXPOSE 6633
CMD ["ryu-manager", "/app/simple_switch_13.py", "/app/sd_policies.py"]
