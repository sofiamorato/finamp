# Guía detallada de pruebas — App Report 4 (Finamp)
**Threading antes/después + Repaint Rainbow (overdraw)**

Dispositivo: **Samsung Galaxy A22 (SM-A225M)**, Android 13. Base de código: commit **2cb01b8** de `finamp-app/finamp` (rama `redesign`).
Tiempo total estimado: **2 a 2.5 horas** (preparación ~45 min, mediciones ~75 min, Rainbow ~25 min).

> Regla de oro: **una sola persona, un solo teléfono, una sola PC** para TODAS las corridas (antes y después). Si cambia el equipo, los números dejan de ser comparables.

---

## PARTE 0 — Qué se va a hacer y por qué (léelo 1 minuto)
- Hay **dos versiones de la misma app**, compiladas del mismo código:
  - **before** = comportamiento original (worker secuencial, cola de descargas con polling).
  - **after** = con las 3 mejoras (worker concurrente, búsqueda con resultados parciales, cola de descargas por eventos).
- Ambas imprimen líneas `[AR4]` en el log (latencias, frames). Esas líneas se capturan con `adb logcat` y un script las resume en tablas.
- Se miden 3 escenarios × 3 repeticiones × 2 versiones = **18 corridas**.
- Aparte, en **modo debug**, se usa **Repaint Rainbow** para ver qué partes de la pantalla se repintan (sección de overdraw del report).

---

## PARTE 1 — Requisitos en la PC (Windows)
| Herramienta | Versión | Verificar con |
|---|---|---|
| Git | cualquiera | `git --version` |
| Flutter | **3.47.x** (el mismo en antes y después) | `flutter --version` |
| Android SDK + platform-tools (adb) | con licencias aceptadas | `flutter doctor` |
| Python | 3.9+ | `python --version` |
| Jellyfin Server | 10.9+ | abre en `http://localhost:8096` |
| Cable USB de datos | — | — |

1. Ejecuta `flutter doctor` y arregla lo que marque en rojo en la sección Android.
2. Si `adb` no está en el PATH, usa la ruta completa: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
3. **Cierra** Android Studio / otros IDE que tengan Gradle abierto (consumen RAM y pueden bloquear el build).

---

## PARTE 2 — Obtener el código y compilar las dos versiones
Usa una ruta **corta** (Windows limita el largo de las rutas): `C:r4\`.

El zip `Finamp_AR4_proyecto.zip` ya trae el proyecto Finamp (commit base **2cb01b8**) **con las modificaciones aplicadas**. No hay que clonar ni aplicar parches.

```powershell
mkdir C:r4
# descomprime Finamp_AR4_proyecto.zip dentro de C:r4  -> queda C:r4inamp-ar4cd C:r4inamp-ar4
flutter pub get
```
Los scripts de captura están en `C:r4inamp-ar4r4_eval\`. Los cambios de código están en: `lib/services/ar4_probe.dart` (nuevo), `jellyfin_api_helper.dart`, `music_providers.dart`, `downloads_service_backend.dart` y `lib/main.dart`.

Compilar (**uno a la vez, nunca dos builds simultáneos** — se pisan los archivos y falla con `PathExistsException`):

```powershell
flutter build apk --profile --dart-define=AR4_AFTER=false
copy build\app\outputs\flutter-apk\app-profile.apk C:\ar4\finamp_before.apk

flutter build apk --profile --dart-define=AR4_AFTER=true
copy build\app\outputs\flutter-apk\app-profile.apk C:\ar4\finamp_after.apk
```
- Cada build tarda 10–15 min la primera vez. Es normal ver avisos de "untranslated messages": no son errores.
- Verifica que existan los dos `.apk` antes de seguir.
- **Modo profile** es obligatorio: debug distorsiona los tiempos.

---

## PARTE 3 — Preparar el teléfono (A22)
1. Ajustes → Acerca del teléfono → Información de software → tocar **Número de compilación** 7 veces.
2. Ajustes → Opciones de desarrollador → activar **Depuración USB**.
3. Conectar al PC y aceptar la huella RSA en el teléfono ("Permitir siempre").
4. En la PC: `adb devices` → debe decir `device` (no `unauthorized`).
5. Condiciones **idénticas en las 18 corridas**:
   - Brillo fijo (p. ej. 50 %), **ahorro de batería OFF**, modo avión OFF, Wi-Fi apagado (se usa USB).
   - Cerrar TODAS las demás apps (recientes → cerrar todo). No usar el teléfono para nada más durante las pruebas.
   - Batería > 50 % y teléfono **a temperatura ambiente** (si está caliente por haber compilado/jugado, espera 10 min; el calor reduce la frecuencia del CPU y ensucia los datos).
   - Pantalla siempre encendida: Opciones de desarrollador → **Mantener activo**.
   - No tocar la pantalla fuera de lo que pide cada escenario.

---

## PARTE 4 — Preparar Jellyfin y la biblioteca
1. Iniciar Jellyfin Server en la PC. Panel `http://localhost:8096`.
2. Usar **la misma biblioteca de las pruebas originales** (con artistas "Machi" y "The Dream"), así S4 queda comparable con la sección 12 del report. Si no la tienes, usa otra y **anota los nombres exactos de artista/álbum** — se declaran en el report.
3. Crear en Jellyfin una **playlist de 10 canciones sin descargar** (~67 MB) para S3. Anotar su nombre.
4. Conectar teléfono ↔ servidor por USB:
   ```powershell
   adb reverse tcp:8096 tcp:8096
   ```
   (Hay que repetirlo cada vez que se reconecta el cable.)
5. Verificar desde el teléfono: Chrome → `http://localhost:8096` debe cargar Jellyfin.

---

## PARTE 5 — Instalar una versión y configurar Finamp
```powershell
adb uninstall com.unicornsonlsd.finamp.profile   # limpia sesión y descargas (ignora el error si no estaba)
adb install C:\ar4\finamp_before.apk
```
(El build profile usa el sufijo `.profile`; el debug usa `.debug`. Ver nombres: `adb shell pm list packages | findstr -i finamp`.)

En el teléfono:
1. Abrir Finamp → agregar servidor `http://localhost:8096` → iniciar sesión → elegir la biblioteca de música.
2. Ajustes: dejar **todo por defecto**. Verificar que *Max concurrent downloads* = **5**.
3. Cerrar la app completamente.

---

## PARTE 6 — El script de captura (cómo se usa)
En la PC, en la carpeta `ar4_eval\` del zip:

```powershell
.\ar4_capture.ps1 -Variant before -Scenario S4 -Run 1
```
- Parámetros: `-Variant before|after`, `-Scenario S3|S4|S5`, `-Run 1|2|3`.
- Hace: limpia el logcat → empieza a grabar → **tú haces el escenario en el teléfono** → vuelves a la PC y presionas **ENTER** → guarda `logs\before_S4_r1.txt` con solo las líneas `[AR4]`.
- Al terminar imprime cuántas líneas guardó. **Si dice 0 líneas, algo falló** (ver Parte 11).
- Si se interrumpe una corrida, **repítela con el mismo número** (sobrescribe el archivo).

Orden recomendado (minimiza reinstalaciones): hacer TODO "before" (9 corridas) y luego TODO "after" (9 corridas).

Antes de **cada** corrida: cerrar Finamp por completo (recientes → deslizar), y abrirlo **después** de lanzar el script y antes de empezar la acción.

---

## PARTE 7 — Escenarios, paso a paso
Cronometra con el reloj. Mismos tiempos en las 18 corridas.

### S4 — Búsqueda y navegación (5 ciclos)  → 3 corridas por versión
1. Lanzar el script (`-Scenario S4 -Run n`). Abrir Finamp. Esperar 5 s en la pantalla principal.
2. Repetir **5 veces** este ciclo:
   1. Pestaña Artists/Albums → tocar el buscador → escribir **"Machi"** → esperar a que carguen resultados.
   2. Abrir el artista → esperar a que cargue → abrir un álbum → esperar 3 s.
   3. Buscar **"The Dream"** → abrir el resultado → esperar 3 s.
   4. Volver a la pantalla principal (atrás hasta Home).
3. Esperar 30 s sin tocar nada → volver a la PC → ENTER.

### S5 — Búsqueda en Home Screen Settings  → 3 corridas por versión
(es el único lugar donde corre `globalSearch`, la función con `Future.wait`)
1. Lanzar el script (`-Scenario S5 -Run n`). Abrir Finamp.
2. Ajustes → **Home Screen** → agregar sección (botón +) → abrir el cuadro de búsqueda.
3. Buscar **estos 5 términos en este orden**, esperando que aparezcan resultados entre uno y otro (≈4 s): `Machi`, `The`, `Dream`, `Love`, `Night`.
4. Salir sin guardar → volver a la PC → ENTER.

### S3 — Descarga de 10 canciones  → 3 corridas por versión
1. **Antes de cada corrida**: borrar descargas previas (Ajustes → Descargas → eliminar todo) o reinstalar la app (Parte 5).
2. Lanzar el script (`-Scenario S3 -Run n`). Abrir Finamp → abrir la playlist de 10 canciones.
3. Tocar **Download → confirmar** en el diálogo. Anotar la hora (reloj).
4. **No tocar nada** hasta que las 10 canciones aparezcan como descargadas (ícono de check). Esperar **15 s más**.
5. Volver a la PC → ENTER. Anotar a mano: duración total de la descarga (segundos).

---

## PARTE 8 — Cambiar de versión
Al terminar las 9 corridas de "before":
```powershell
adb uninstall com.unicornsonlsd.finamp.profile
adb install C:\ar4\finamp_after.apk
```
Repite Parte 5 (login) y haz las 9 corridas con `-Variant after`.

---

## PARTE 9 — Resumen de resultados
```powershell
python ar4_summary.py
```
Imprime tablas (n / media / mediana / p90) de: latencia del worker, peticiones simultáneas, tiempo de `globalSearch`, espera de slot de descarga y tiempos de frame (build/raster, % de frames lentos). **Guarda la salida en un .txt** y adjúntala.

---

## PARTE 10 — Capturas de pantalla de DevTools (una vez por versión, escenario S4)
1. Con la app corriendo en modo profile: `flutter run --profile --dart-define=AR4_AFTER=false` (o `true`) en la carpeta del repo, con el A22 conectado.
2. Abrir DevTools (el enlace que imprime la consola) → pestaña **Performance**.
3. Hacer 2 ciclos de S4 → en **Timeline events** buscar el filtro **"AR4"**.
4. Tomar captura mostrando las barras `AR4 ...`: en *before* las peticiones aparecen una tras otra ("escalera"); en *after* se solapan.
5. Capturas necesarias: `devtools_before_S4.png`, `devtools_after_S4.png`, y la del **frame chart** (barras UI/Raster) de cada una.

---

## PARTE 11 — Repaint Rainbow (overdraw) — modo DEBUG
Estos indicadores solo existen en debug. Los tiempos aquí **no** se usan; es solo observación visual.

```powershell
flutter run --dart-define=AR4_AFTER=false
```
1. En DevTools → pestaña **Flutter Inspector** → activar **Highlight Repaints** (Repaint Rainbow). Activar también **Highlight Oversized Images**.
2. Qué significa: cada capa repintada recibe un borde de color que **cambia de color cada vez que se repinta**. Una región estática cuyo color cambia sin parar = repintado innecesario.
3. Por cada vista, hacer la acción **10 segundos** y tomar captura (o grabar la pantalla):

| Vista | Acción | Qué observar y anotar |
|---|---|---|
| **Songs** | Scroll; luego con una canción sonando (fila con visualizador animado) | ¿Se repinta solo el visualizador o toda la fila/lista? ¿Los bordes de las filas cambian al hacer scroll? |
| **Reproductor completo** | Abrir con fondo difuminado activo, dejar correr 10 s | ¿El fondo blur cambia de color (se repinta) o queda fijo? ¿La barra de progreso se repinta aparte del resto? |
| **Diálogo de descarga** | Abrir en una playlist y descargar | ¿Qué se repinta mientras avanza el progreso? ¿Toda la pantalla o solo el diálogo? |
| **Búsqueda** | Escribir un término y ver resultados | ¿Se repinta la lista completa al escribir cada letra? |

4. Opcional (Performance → ⋮ opciones): desactivar **Render Opacity / Clip layers** y comparar tiempos raster.
5. Repetir una vez la captura de Android "Depurar exceso de GPU" (Opciones de desarrollador) solo como **contraste**: se verá todo azul porque Android no ve dentro de la superficie de Flutter.
6. Anotar por vista (1–2 frases): "región X cambia de color N veces/10 s" o "región X estable".

---

## PARTE 12 — Qué devolver (lista de verificación)
- [ ] Carpeta `ar4_eval\logs\` con **18 archivos** (`before_S3_r1.txt` … `after_S5_r3.txt`)
- [ ] Salida de `python ar4_summary.py` guardada en `resumen.txt`
- [ ] Duración manual de la descarga S3 (6 valores, en segundos)
- [ ] 4 capturas DevTools (`devtools_{before,after}_S4.png` + frame charts)
- [ ] Capturas/GIF de Rainbow de las 4 vistas + tus notas
- [ ] Captura de "Depurar exceso de GPU" (contraste)
- [ ] Nombres exactos de artistas/álbum/playlist usados, modelo, versión de Android y de Flutter (`flutter --version`)
- [ ] Confirmar que usaron el zip sin modificar el código (el zip está basado en el commit 2cb01b8)

---

## PARTE 13 — Si algo falla
| Síntoma | Causa probable | Solución |
|---|---|---|
| `adb devices` vacío o `unauthorized` | Cable solo-carga / sin permiso | Cambiar cable; revocar autorizaciones USB y reconectar |
| El script dice **0 líneas AR4** | App cerrada, logs filtrados | Verifica con `adb logcat -d -s flutter \| findstr AR4`; confirma que instalaste un APK **profile** |
| La app no conecta al servidor | Falta el reverse | `adb reverse tcp:8096 tcp:8096` y probar en Chrome del teléfono |
| Build falla con `PathExistsException` | Dos builds a la vez | Esperar a que uno termine; `flutter clean` y reintentar |
| Teléfono muy caliente / lento | Throttling térmico | Pausa 10 min; no compiles mientras mides |
| Una corrida salió rara (interrupción, llamada) | — | Repetir esa corrida con el mismo número |

---

## Nota de integridad
El syllabus del curso prohíbe incluir contenido generado por IA en la entrega final. Esta guía y los textos que se redacten son **borrador**: usen los datos medidos y reescriban con sus propias palabras.
