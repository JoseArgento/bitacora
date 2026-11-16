<#
.SYNOPSIS
    Bitácora · ayudante de capturas (capture helper).

.DESCRIPTION
    El juego no deja que un addon cree carpetas, lea el portapapeles ni vea qué archivos hay. Este script lo
    hace desde afuera, para el addon Bitácora de WoW Forever:

      Instalar  crea Interface\AddOns\BitacoraImagenes (una carpeta-addon con su lista, Indice.lua), convierte
                las imágenes que ya hubiera ahí y deja en el Escritorio un atajo con Ctrl+Alt+V.
      Pegar     guarda en esa carpeta la imagen que está en el portapapeles (o el archivo de imagen copiado en
                el Explorador; si no hay ninguna, tu última captura del juego).
      Traer     copia ahí tus últimas capturas del juego (Screenshots\WoWScrnShot_*.jpg).
      Indice    vuelve a escribir la lista.

    Cada imagen se guarda como TGA de lados potencia de dos (lo que el juego seguro sabe cargar); su forma
    real va en la lista y Bitácora la muestra con esa forma.

    No usa la red, no pide permisos de administrador y solo escribe en tres lugares: la carpeta
    BitacoraImagenes del juego, %APPDATA%\BitacoraCapturas (dónde está el juego) y, al instalar, un atajo en
    el Escritorio.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -STA -File Capturas.ps1 -Accion Instalar
#>
[CmdletBinding()]
param(
    [ValidateSet('Instalar', 'Pegar', 'Traer', 'Indice')]
    [string]$Accion = 'Pegar',
    # La carpeta _forever_ del juego. Sin esto, la busca (y la recuerda).
    [string]$Juego = '',
    # Un archivo de imagen para guardar, en vez del portapapeles.
    [string]$Imagen = '',
    # Traer: cuántas capturas del juego, las más nuevas primero.
    [int]$Cuantas = 10,
    # Instalar: no crear el atajo del Escritorio.
    [switch]$SinAtajo,
    # Sin globos de aviso ni ventanas para elegir carpeta (para pruebas).
    [switch]$Silencioso
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$NOMBRE_ADDON = 'BitacoraImagenes'
$TOTAL_HUECOS = 24          # archivos vacíos que esperan una captura (ver Completar-Huecos)
$HUECO_BYTES = 200    # un hueco libre pesa menos que esto
$LADO_MAX = 1024
$SIN_BOM = New-Object System.Text.UTF8Encoding($false)

# (PowerShell no distingue mayúsculas en los nombres de variables: cada nombre de este archivo es único)
$HABLA_ES = ((Get-UICulture).TwoLetterISOLanguageName -eq 'es')
function T([string]$TextoEs, [string]$TextoEn) { if ($HABLA_ES) { return $TextoEs } return $TextoEn }

# --- avisos -----------------------------------------------------------------------------------------

function Avisar([string]$Texto) {
    Write-Host $Texto
    if ($Silencioso) { return }
    try {
        $icono = New-Object System.Windows.Forms.NotifyIcon
        $icono.Icon = [System.Drawing.SystemIcons]::Information
        $icono.Visible = $true
        $icono.ShowBalloonTip(6000, 'Bitácora', $Texto, [System.Windows.Forms.ToolTipIcon]::Info)
        Start-Sleep -Seconds 6
        $icono.Dispose()
    } catch { }
}

# --- dónde está el juego -------------------------------------------------------------------------------

function Es-Juego([string]$Ruta) {
    if (-not $Ruta) { return $false }
    if (-not (Test-Path -LiteralPath $Ruta -PathType Container)) { return $false }
    if (Test-Path -LiteralPath (Join-Path $Ruta 'Interface') -PathType Container) { return $true }
    return (@(Get-ChildItem -LiteralPath $Ruta -Filter 'Wow*.exe' -ErrorAction SilentlyContinue).Count -gt 0)
}

function Archivo-Config {
    $base = $env:APPDATA
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    return (Join-Path (Join-Path $base 'BitacoraCapturas') 'juego.txt')
}

function Buscar-Juego {
    if ($Juego) {
        # dicho a mano: esa carpeta, o su _forever_ si pasaron la de World of Warcraft
        foreach ($c in @($Juego, (Join-Path $Juego '_forever_'))) {
            if (Es-Juego $c) { return (Resolve-Path -LiteralPath $c).Path }
        }
        return $null
    }
    $candidatos = New-Object System.Collections.Generic.List[string]
    $config = Archivo-Config
    if (Test-Path -LiteralPath $config) {
        $guardado = ([System.IO.File]::ReadAllText($config)).Trim()
        if ($guardado) { $candidatos.Add($guardado) }
    }
    foreach ($clave in @('HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft', 'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft')) {
        try {
            $instalado = (Get-ItemProperty -Path $clave -ErrorAction Stop).InstallPath
            if ($instalado) {
                $instalado = $instalado.TrimEnd('\')
                $candidatos.Add((Join-Path $instalado '_forever_'))
                $candidatos.Add((Join-Path (Split-Path -Path $instalado -Parent) '_forever_'))
            }
        } catch { }
    }
    foreach ($disco in [System.IO.DriveInfo]::GetDrives()) {
        if ($disco.DriveType -ne [System.IO.DriveType]::Fixed) { continue }
        foreach ($sub in @('Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft', 'World of Warcraft', 'Games\World of Warcraft', 'Juegos\World of Warcraft')) {
            $candidatos.Add((Join-Path $disco.Name (Join-Path $sub '_forever_')))
        }
    }
    foreach ($c in $candidatos) {
        if (Es-Juego $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    if ($Silencioso) { return $null }
    $dialogo = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialogo.Description = (T 'Elegí la carpeta _forever_ del juego (adentro de World of Warcraft)' 'Pick the game''s _forever_ folder (inside World of Warcraft)')
    $dialogo.ShowNewFolderButton = $false
    if ($dialogo.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($c in @($dialogo.SelectedPath, (Join-Path $dialogo.SelectedPath '_forever_'))) {
            if (Es-Juego $c) { return (Resolve-Path -LiteralPath $c).Path }
        }
    }
    return $null
}

function Recordar-Juego([string]$Ruta) {
    if ($Juego) { return }   # dicho a mano (pruebas): no se guarda
    try {
        $config = Archivo-Config
        [void][System.IO.Directory]::CreateDirectory((Split-Path -Path $config -Parent))
        [System.IO.File]::WriteAllText($config, $Ruta, $SIN_BOM)
    } catch { }
}

function Juego-Abierto {
    return (@(Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue).Count -gt 0)
}

# --- texturas TGA --------------------------------------------------------------------------------------

function Potencia2([double]$N) {
    if ($N -lt 1) { $N = 1 }
    $p = [int][Math]::Pow(2, [Math]::Round([Math]::Log($N, 2)))
    if ($p -lt 64) { $p = 64 }
    if ($p -gt $LADO_MAX) { $p = $LADO_MAX }
    return $p
}

# Guarda la imagen como TGA de 32 bits sin comprimir, filas de abajo hacia arriba (igual que las texturas
# que el juego ya carga de estos addons), con lados potencia de dos: achicada hasta $LADO_MAX y apretada al
# cuadro. La forma real se anota en la lista.
function Guardar-Tga([System.Drawing.Image]$Origen, [string]$Destino) {
    $escala = [Math]::Min(1.0, $LADO_MAX / [double][Math]::Max($Origen.Width, $Origen.Height))
    $tw = Potencia2 ($Origen.Width * $escala)
    $th = Potencia2 ($Origen.Height * $escala)
    $bmp = New-Object System.Drawing.Bitmap($tw, $th, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $atributos = New-Object System.Drawing.Imaging.ImageAttributes
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Black)   # fondo opaco: lo transparente de un PNG queda negro
        $atributos.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)   # sin borde oscuro
        $cuadro = New-Object System.Drawing.Rectangle(0, 0, $tw, $th)
        $g.DrawImage($Origen, $cuadro, 0, 0, $Origen.Width, $Origen.Height, [System.Drawing.GraphicsUnit]::Pixel, $atributos)
    } finally {
        $atributos.Dispose()
        $g.Dispose()
    }
    $cuadro = New-Object System.Drawing.Rectangle(0, 0, $tw, $th)
    $bits = $bmp.LockBits($cuadro, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $paso = [Math]::Abs($bits.Stride)
        $bytes = New-Object byte[] ($paso * $th)
        [System.Runtime.InteropServices.Marshal]::Copy($bits.Scan0, $bytes, 0, $bytes.Length)
    } finally {
        $bmp.UnlockBits($bits)
        $bmp.Dispose()
    }
    $cabecera = New-Object byte[] 18
    $cabecera[2] = 2                       # color verdadero, sin comprimir
    $cabecera[12] = $tw -band 0xFF
    $cabecera[13] = ($tw -shr 8) -band 0xFF
    $cabecera[14] = $th -band 0xFF
    $cabecera[15] = ($th -shr 8) -band 0xFF
    $cabecera[16] = 32
    $cabecera[17] = 8                      # 8 bits de alfa; origen abajo a la izquierda
    $temporal = $Destino + '.tmp'
    $salida = [System.IO.File]::Create($temporal)
    try {
        $salida.Write($cabecera, 0, 18)
        for ($y = $th - 1; $y -ge 0; $y--) {
            $salida.Write($bytes, $y * $paso, $tw * 4)   # BGRA, como lo quiere el TGA
        }
    } finally {
        $salida.Dispose()
    }
    # el archivo queda en su lugar de una vez (un hueco se pisa: el juego ya sabe que ese nombre existe)
    Copy-Item -LiteralPath $temporal -Destination $Destino -Force
    Remove-Item -LiteralPath $temporal -Force
}

function Medidas-Tga([string]$Ruta) {
    $f = [System.IO.File]::OpenRead($Ruta)
    try {
        $c = New-Object byte[] 18
        if ($f.Read($c, 0, 18) -lt 18) { return $null }
        return @(($c[12] + 256 * $c[13]), ($c[14] + 256 * $c[15]))
    } finally {
        $f.Dispose()
    }
}

function Abrir-Imagen([string]$Ruta) {
    # desde memoria: el archivo no queda tomado
    $bytes = [System.IO.File]::ReadAllBytes($Ruta)
    $flujo = New-Object System.IO.MemoryStream(, $bytes)
    return [System.Drawing.Image]::FromStream($flujo)
}

# --- la carpeta y su lista -----------------------------------------------------------------------------

function Nombre-Hueco([int]$N) { return ('captura_{0:D3}.tga' -f $N) }

function Es-Hueco-Libre([System.IO.FileInfo]$Archivo) {
    return ($Archivo.Name -match '^captura_\d{3}\.tga$' -and $Archivo.Length -lt $HUECO_BYTES)
}

# Un archivo nuevo no existe para el juego hasta que se lo reinicia, pero uno que ya estaba y cambia sí se
# ve con /reload. Por eso la carpeta guarda "huecos": archivos mínimos, con nombre, que una captura pisa.
function Completar-Huecos([string]$Carpeta) {
    $libres = @(Get-ChildItem -LiteralPath $Carpeta -Filter 'captura_*.tga' | Where-Object { Es-Hueco-Libre $_ }).Count
    $vacio = New-Object byte[] (18 + 4 * 4 * 4)
    $vacio[2] = 2; $vacio[12] = 4; $vacio[14] = 4; $vacio[16] = 32; $vacio[17] = 8
    $n = 1
    while ($libres -lt $TOTAL_HUECOS -and $n -le 999) {
        $ruta = Join-Path $Carpeta (Nombre-Hueco $n)
        if (-not (Test-Path -LiteralPath $ruta)) {
            [System.IO.File]::WriteAllBytes($ruta, $vacio)
            $libres++
        }
        $n++
    }
}

function Primer-Hueco([string]$Carpeta) {
    $libre = @(Get-ChildItem -LiteralPath $Carpeta -Filter 'captura_*.tga' | Where-Object { Es-Hueco-Libre $_ } | Sort-Object Name)
    if ($libre.Count -gt 0) { return $libre[0].FullName }
    return $null
}

function Nombre-Seguro([string]$Nombre) {
    # lo que Bitácora acepta como nombre de imagen: letras sin acento, números, - _ .
    $limpio = ($Nombre -replace '[^A-Za-z0-9_.-]', '_')
    if ($limpio.Length -gt 60) { $limpio = $limpio.Substring(0, 60) }
    return $limpio
}

function Unix([datetime]$Fecha) {
    return [int64]([DateTimeOffset]$Fecha).ToUnixTimeSeconds()
}

# datos.tsv: archivo, ancho, alto, cuándo (unix), sello de captura del juego, archivo de origen, título
function Leer-Datos([string]$Carpeta) {
    $datos = @{}
    $ruta = Join-Path $Carpeta 'datos.tsv'
    if (Test-Path -LiteralPath $ruta) {
        foreach ($linea in [System.IO.File]::ReadAllLines($ruta, $SIN_BOM)) {
            $p = $linea.Split("`t")
            if ($p.Length -ge 7 -and $p[0]) {
                $datos[$p[0]] = @{ file = $p[0]; w = [int]$p[1]; h = [int]$p[2]; t = [int64]$p[3]; shot = $p[4]; from = $p[5]; title = $p[6] }
            }
        }
    }
    return $datos
}

function Guardar-Datos([string]$Carpeta, [hashtable]$Datos) {
    $lineas = New-Object System.Collections.Generic.List[string]
    foreach ($clave in ($Datos.Keys | Sort-Object)) {
        $d = $Datos[$clave]
        $titulo = ([string]$d.title -replace '[\t\r\n]', ' ')
        $lineas.Add(($d.file, $d.w, $d.h, $d.t, $d.shot, $d.from, $titulo) -join "`t")
    }
    [System.IO.File]::WriteAllLines((Join-Path $Carpeta 'datos.tsv'), $lineas, $SIN_BOM)
}

function Texto-Lua([string]$Texto) {
    $t = ($Texto -replace '[\x00-\x1F]', ' ')
    $t = $t.Replace('\', '\\').Replace('"', '\"')
    return '"' + $t + '"'
}

# Vuelve a escribir Indice.lua (y el .toc) con lo que hay de verdad en la carpeta.
function Escribir-Indice([string]$Carpeta, [hashtable]$Datos) {
    # lo que está en datos pero ya no está en el disco (o volvió a ser un hueco) se olvida
    foreach ($clave in @($Datos.Keys)) {
        $ruta = Join-Path $Carpeta $clave
        if (-not (Test-Path -LiteralPath $ruta) -or (Get-Item -LiteralPath $ruta).Length -lt $HUECO_BYTES) {
            $Datos.Remove($clave)
        }
    }
    # texturas que alguien dejó a mano y no están anotadas
    foreach ($a in @(Get-ChildItem -LiteralPath $Carpeta -File | Where-Object { $_.Extension -match '^\.(tga|blp)$' })) {
        if ($Datos.ContainsKey($a.Name) -or (Es-Hueco-Libre $a) -or $a.Name -ne (Nombre-Seguro $a.Name)) { continue }
        $w = 0; $h = 0
        if ($a.Extension -ieq '.tga') {
            $m = Medidas-Tga $a.FullName
            if ($m) { $w = $m[0]; $h = $m[1] }
        }
        $Datos[$a.Name] = @{ file = $a.Name; w = $w; h = $h; t = (Unix $a.LastWriteTime); shot = ''; from = ''; title = [System.IO.Path]::GetFileNameWithoutExtension($a.Name) }
    }
    Guardar-Datos $Carpeta $Datos

    $lineas = New-Object System.Collections.Generic.List[string]
    $lineas.Add('-- Hecho por el ayudante de capturas de Bitacora (ayudante/Capturas.ps1). No lo edites: se escribe solo.')
    $lineas.Add('BitacoraImagenesIndice = {')
    $lineas.Add("`tversion = 1,")
    $lineas.Add("`tmade = " + (Unix (Get-Date)) + ',')
    $lineas.Add("`timages = {")
    foreach ($d in ($Datos.Values | Sort-Object { $_.t } -Descending)) {
        $campos = New-Object System.Collections.Generic.List[string]
        $campos.Add('file = ' + (Texto-Lua $d.file))
        $campos.Add('title = ' + (Texto-Lua $d.title))
        if ($d.w -gt 0 -and $d.h -gt 0) {
            $campos.Add('w = ' + $d.w)
            $campos.Add('h = ' + $d.h)
        }
        $campos.Add('t = ' + $d.t)
        if ($d.shot) { $campos.Add('shot = ' + (Texto-Lua $d.shot)) }
        if ($d.from -and $d.from -eq (Nombre-Seguro $d.from)) { $campos.Add('from = ' + (Texto-Lua $d.from)) }
        $lineas.Add("`t`t{ " + ($campos -join ', ') + ' },')
    }
    $lineas.Add("`t},")
    $lineas.Add('}')
    [System.IO.File]::WriteAllLines((Join-Path $Carpeta 'Indice.lua'), $lineas, $SIN_BOM)

    $toc = @(
        '## Interface: 16001',
        '## Title: Bitácora · Imágenes',
        '## Notes: Your pictures for Bitácora''s notes and album. Written by the capture helper; the list is Indice.lua.',
        '## Notes-esES: Tus imágenes para las notas y el álbum de Bitácora. La escribe el ayudante de capturas; la lista es Indice.lua.',
        '## Notes-esMX: Tus imágenes para las notas y el álbum de Bitácora. La escribe el ayudante de capturas; la lista es Indice.lua.',
        '## Author: José Argento',
        '## Version: 1',
        '',
        'Indice.lua',
        ''
    )
    [System.IO.File]::WriteAllLines((Join-Path $Carpeta ($NOMBRE_ADDON + '.toc')), $toc, $SIN_BOM)
    return $Datos.Count
}

# Las imágenes sueltas que ya estaban en la carpeta (png, jpg...) pasan a TGA con el mismo nombre; la nota
# que decía "foto.png" encuentra "foto.tga" por el nombre.
function Convertir-Sueltas([string]$Carpeta, [hashtable]$Datos) {
    $hechas = 0
    foreach ($a in @(Get-ChildItem -LiteralPath $Carpeta -File | Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|bmp|gif)$' })) {
        $base = Nombre-Seguro ([System.IO.Path]::GetFileNameWithoutExtension($a.Name))
        $destino = $base + '.tga'
        if ($Datos.ContainsKey($destino) -or (Test-Path -LiteralPath (Join-Path $Carpeta $destino))) { continue }
        try {
            $img = Abrir-Imagen $a.FullName
            try {
                Guardar-Tga $img (Join-Path $Carpeta $destino)
                $Datos[$destino] = @{ file = $destino; w = $img.Width; h = $img.Height; t = (Unix $a.LastWriteTime); shot = ''; from = $a.Name; title = $base }
                $hechas++
            } finally {
                $img.Dispose()
            }
        } catch {
            Write-Host ((T 'No pude convertir ' 'Could not convert ') + $a.Name + ': ' + $_.Exception.Message)
        }
    }
    return $hechas
}

# Guarda una imagen: en el primer hueco libre, o con nombre nuevo si no queda ninguno.
# Devuelve @{ file; nuevo = $true si es un archivo que el juego abierto todavía no conoce }.
function Agregar-Imagen([string]$Carpeta, [hashtable]$Datos, [System.Drawing.Image]$Img, [string]$Titulo, [string]$Sello, [string]$NombreNuevo, [datetime]$Fecha) {
    $destino = Primer-Hueco $Carpeta
    $nuevo = $false
    if (-not $destino) {
        $nuevo = $true
        $nombre = Nombre-Seguro $NombreNuevo
        $destino = Join-Path $Carpeta ($nombre + '.tga')
        $n = 2
        while (Test-Path -LiteralPath $destino) {
            $destino = Join-Path $Carpeta ($nombre + '_' + $n + '.tga')
            $n++
        }
    }
    Guardar-Tga $Img $destino
    $archivo = [System.IO.Path]::GetFileName($destino)
    $Datos[$archivo] = @{ file = $archivo; w = $Img.Width; h = $Img.Height; t = (Unix $Fecha); shot = $Sello; from = ''; title = $Titulo }
    return @{ file = $archivo; nuevo = $nuevo }
}

function Capturas-Sin-Traer([string]$RutaJuego, [hashtable]$Datos) {
    $carpeta = Join-Path $RutaJuego 'Screenshots'
    if (-not (Test-Path -LiteralPath $carpeta -PathType Container)) { return @() }
    $traidas = @{}
    foreach ($d in $Datos.Values) { if ($d.shot) { $traidas[$d.shot] = $true } }
    $lista = @(Get-ChildItem -LiteralPath $carpeta -File |
        Where-Object { $_.Name -match '^WoWScrnShot_(\d{6}_\d{6})\.(jpg|jpeg|png|bmp)$' -and -not $traidas.ContainsKey($Matches[1]) } |
        Sort-Object LastWriteTime -Descending)
    return $lista
}

function Traer-Captura([string]$Carpeta, [hashtable]$Datos, [System.IO.FileInfo]$Archivo) {
    [void]($Archivo.Name -match '^WoWScrnShot_(\d{6}_\d{6})\.')
    $sello = $Matches[1]
    $img = Abrir-Imagen $Archivo.FullName
    try {
        $titulo = (T 'Captura del juego ' 'Game screenshot ') + $Archivo.LastWriteTime.ToString('dd/MM HH:mm')
        return (Agregar-Imagen $Carpeta $Datos $img $titulo $sello ('WoWScrnShot_' + $sello) $Archivo.LastWriteTime)
    } finally {
        $img.Dispose()
    }
}

function Imagen-Del-Portapapeles {
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
            $img = [System.Windows.Forms.Clipboard]::GetImage()
            if ($img) { return @{ img = $img; nombre = '' } }
        }
        if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
            foreach ($f in [System.Windows.Forms.Clipboard]::GetFileDropList()) {
                if ($f -match '\.(png|jpg|jpeg|bmp|gif)$' -and (Test-Path -LiteralPath $f -PathType Leaf)) {
                    return @{ img = (Abrir-Imagen $f); nombre = [System.IO.Path]::GetFileNameWithoutExtension($f) }
                }
            }
        }
    } catch { }
    return $null
}

function Crear-Atajo {
    $escritorio = [Environment]::GetFolderPath('Desktop')
    $shell = New-Object -ComObject WScript.Shell
    $atajo = $shell.CreateShortcut((Join-Path $escritorio 'Pegar captura en Bitácora.lnk'))
    $atajo.TargetPath = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
    $atajo.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $PSCommandPath + '" -Accion Pegar'
    $atajo.WorkingDirectory = $PSScriptRoot
    $atajo.Hotkey = 'CTRL+ALT+V'
    $atajo.WindowStyle = 7
    $atajo.Description = (T 'Guarda en Bitácora la imagen del portapapeles (Ctrl+Alt+V)' 'Saves the clipboard picture for Bitácora (Ctrl+Alt+V)')
    $atajo.Save()
}

# --- las acciones ---------------------------------------------------------------------------------------

$rutaJuego = Buscar-Juego
if (-not $rutaJuego) {
    Avisar (T 'No encontré la carpeta _forever_ del juego. Abrí «Instalar» y elegila.' 'Could not find the game''s _forever_ folder. Run "Instalar" and pick it.')
    exit 1
}
Recordar-Juego $rutaJuego

$addons = Join-Path (Join-Path $rutaJuego 'Interface') 'AddOns'
$carpeta = Join-Path $addons $NOMBRE_ADDON
$eraNueva = -not (Test-Path -LiteralPath $carpeta -PathType Container)
[void][System.IO.Directory]::CreateDirectory($carpeta)
$datos = Leer-Datos $carpeta
$abierto = Juego-Abierto
$reiniciar = (T ' Cerrá el juego y volvé a abrirlo una vez para que vea los archivos nuevos.' ' Close the game and open it again once so it sees the new files.')

if ($Accion -eq 'Instalar') {
    $convertidas = Convertir-Sueltas $carpeta $datos
    Completar-Huecos $carpeta
    $total = Escribir-Indice $carpeta $datos
    $texto = (T 'Listo. Carpeta de imágenes: ' 'Done. Pictures folder: ') + $carpeta + '. ' + $total + (T ' imágenes en la lista' ' pictures in the list')
    if ($convertidas -gt 0) { $texto += ' (' + $convertidas + (T ' convertidas' ' converted') + ')' }
    $texto += '.'
    if (-not $SinAtajo) {
        try {
            Crear-Atajo
            $texto += (T ' En el Escritorio quedó «Pegar captura en Bitácora»: Ctrl+Alt+V guarda lo que copiaste.' ' "Pegar captura en Bitácora" is on your Desktop: Ctrl+Alt+V saves what you copied.')
        } catch {
            $texto += (T ' No pude crear el atajo del Escritorio; usá «Pegar captura.bat».' ' Could not create the Desktop shortcut; use "Pegar captura.bat".')
        }
    }
    if ($abierto) { $texto += $reiniciar }
    Avisar $texto
    exit 0
}

if ($Accion -eq 'Indice') {
    if (-not $abierto) { Completar-Huecos $carpeta }
    $total = Escribir-Indice $carpeta $datos
    Avisar ('' + $total + (T ' imágenes en la lista.' ' pictures in the list.'))
    exit 0
}

if ($Accion -eq 'Traer') {
    $pendientes = @(Capturas-Sin-Traer $rutaJuego $datos)
    if ($Cuantas -lt 1) { $Cuantas = 1 }
    $traidas = 0; $nuevas = 0
    foreach ($a in ($pendientes | Select-Object -First $Cuantas)) {
        try {
            $r = Traer-Captura $carpeta $datos $a
            $traidas++
            if ($r.nuevo) { $nuevas++ }
        } catch {
            Write-Host ((T 'No pude traer ' 'Could not bring ') + $a.Name + ': ' + $_.Exception.Message)
        }
    }
    if (-not $abierto) { Completar-Huecos $carpeta }
    [void](Escribir-Indice $carpeta $datos)
    $texto = '' + $traidas + (T ' capturas del juego traídas' ' game screenshots brought')
    $quedan = $pendientes.Count - $traidas
    if ($quedan -gt 0) { $texto += ' (' + (T 'quedan ' '') + $quedan + (T ' más viejas' ' older ones left') + ')' }
    $texto += (T '. En el juego: Recargar (/reload).' '. In the game: Reload (/reload).')
    if ($abierto -and ($nuevas -gt 0 -or $eraNueva)) { $texto += $reiniciar }
    Avisar $texto
    exit 0
}

# Pegar: un archivo dicho a mano, el portapapeles o, si no hay nada, la última captura del juego
$resultado = $null
$titulo = ''
if ($Imagen) {
    if (-not (Test-Path -LiteralPath $Imagen -PathType Leaf)) {
        Avisar ((T 'No existe el archivo ' 'No such file: ') + $Imagen)
        exit 1
    }
    $img = Abrir-Imagen $Imagen
    try {
        $titulo = [System.IO.Path]::GetFileNameWithoutExtension($Imagen)
        $resultado = Agregar-Imagen $carpeta $datos $img $titulo '' ('imagen_' + (Get-Date).ToString('yyyyMMdd_HHmmss')) (Get-Date)
    } finally {
        $img.Dispose()
    }
} else {
    $copiada = Imagen-Del-Portapapeles
    if ($copiada) {
        try {
            $titulo = $copiada.nombre
            if (-not $titulo) { $titulo = (T 'Captura ' 'Capture ') + (Get-Date).ToString('dd/MM HH:mm') }
            $resultado = Agregar-Imagen $carpeta $datos $copiada.img $titulo '' ('pegada_' + (Get-Date).ToString('yyyyMMdd_HHmmss')) (Get-Date)
        } finally {
            $copiada.img.Dispose()
        }
    } else {
        $pendientes = @(Capturas-Sin-Traer $rutaJuego $datos)
        if ($pendientes.Count -gt 0) {
            $resultado = Traer-Captura $carpeta $datos $pendientes[0]
            $titulo = $datos[$resultado.file].title
        }
    }
}

if (-not $resultado) {
    [void](Escribir-Indice $carpeta $datos)
    Avisar (T 'No hay ninguna imagen en el portapapeles ni capturas del juego sin traer. Copiá una (Win+Shift+S) y probá de nuevo.' 'There is no picture in the clipboard and no game screenshot left to bring. Copy one (Win+Shift+S) and try again.')
    exit 2
}

if (-not $abierto) { Completar-Huecos $carpeta }
[void](Escribir-Indice $carpeta $datos)
$texto = (T 'Guardada: «' 'Saved: "') + $titulo + (T '». En el juego: Agregar imagen, Recargar, y elegila de la lista.' '". In the game: Add image, Reload, and pick it from the list.')
if ($abierto -and ($resultado.nuevo -or $eraNueva)) { $texto += $reiniciar }
Avisar $texto
exit 0
