# Ejecutar en PowerShell (Windows). Deja la ventana abierta.
param([string]$Codespace = "cuddly-bassoon-966v6pj7pvwphp9wj")
gh codespace ports forward 3080:3080 5000:5000 5001:5001 5002:5002 5003:5003 5004:5004 5005:5005 -c $Codespace
