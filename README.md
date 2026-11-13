# nebula-connect-lab
Nebula Connect laboratory distribution only

## Nebula Connect para Windows

Windows PowerShell administrativo, instalación del servicio recomendado:

```powershell
iex (iwr -useb https://raw.githubusercontent.com/diegotubito/nebula-connect-lab/main/connect.ps1).Content
```

Versión exacta:

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/diegotubito/nebula-connect-lab/main/connect.ps1).Content)) 0.3.0-rc.1
```

La dirección es permanente. El instalador selecciona únicamente versiones publicadas y verifica el SHA-256 del paquete completo. 0.3.0-rc.1 identifica la distribución del servicio Windows publicada originalmente con el tag h2-win-pilot.1. Es una versión preliminar. El servicio existente conserva su identidad Windows. macOS sigue en la distribución CLI H1.
