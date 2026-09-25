# GNS3 Server Daemon + SSH DevContainer en GitHub Codespaces

Repositorio y entorno reproducible para ejecutar **GNS3 Server en modo demonio (0.0.0.0:3080)** y acceso **SSH** dentro de GitHub Codespaces.

---

## 🚀 Características del Entorno

- **GNS3 Server Daemon**: Ejecutándose en segundo plano en el puerto `3080`.
- **Acceso SSH Dual**:
  - Directo mediante GitHub CLI: `gh codespace ssh -c <codespace-name>`
  - Servidor OpenSSH corriendo en el puerto `2222`.
- **Motores de Emulación y Simulación**:
  - `Dynamips` (routers Cisco IOS)
  - `VPCS` (Virtual PC Simulator)
  - `uBridge` (interconexión de interfaces)
  - `QEMU` (x86_64 software emulation)
- **Puertos de Consola Telnet**: Puertos `5000-5005` pre-configurados para acceso a consolas de nodos.
- **Persistencia**: Rutas listas en `/home/vscode/GNS3/projects` e `/home/vscode/GNS3/images`.

---

## 📡 Cómo Conectarse

### 1. Web UI de GNS3
Una vez iniciado el Codespace, el puerto `3080` se reenviará automáticamente. Abrí tu navegador en:
`https://<codespace-name>-3080.app.github.dev` (o `http://localhost:3080` si usás VS Code Local / SSH Port Forward).

### 2. Acceso por SSH (GitHub CLI)
```bash
# Conexión directa mediante terminal
gh codespace ssh -c <codespace-name>
```

### 3. Conexión desde el Cliente Desktop de GNS3 GUI
Podés apuntar tu cliente de escritorio GNS3 local al Codespace:
1. En tu máquina local, creá un túnel de puertos con GitHub CLI:
   ```bash
   gh codespace ports forward 3080:3080 -c <codespace-name>
   ```
2. En **GNS3 Desktop Client**:
   - Andá a **Preferences** -> **Server** -> **Main server**.
   - Desmarcá *Enable local server*.
   - **Host**: `127.0.0.1`
   - **Port**: `3080`
   - Hacé clic en **Apply**.

---

## 🛠️ Comandos Útiles dentro del Codespace

- **Ver estado del demonio GNS3**:
  ```bash
  ps aux | grep gns3server
  cat /tmp/gns3server.log
  ```
- **Reiniciar el servidor GNS3**:
  ```bash
  pkill -f gns3server
  nohup gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf > /tmp/gns3server.log 2>&1 &
  ```
- **Verificar puertos escuchando**:
  ```bash
  netstat -tlpn
  ```
