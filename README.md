# Hortalizas POS

Sistema POS para comercio mayorista/minorista de hortalizas, con tres apps
sincronizadas: **Vendedor**, **Caja** y **Administrador**. Offline-first
(SQLite) con sincronización en tiempo real (Firebase).

## Estado actual del proyecto

**Fase 1 (flujo de venta local) — COMPLETA.**
**Fase 2 (sincronización + login) — COMPLETA.**
**Fase 3 (caja completa) — COMPLETA.**
**Fase 4 (administración) — COMPLETA.**

> **Nota sobre revisión de código:** este proyecto se armó en un entorno
> sin Flutter/Dart SDK instalado (no hay forma de correr `flutter analyze`
> ni un emulador acá). Se hizo una revisión manual exhaustiva línea por
> línea de todo `lib/` (imports, firmas de constructores, tipos, wiring
> de providers) simulando dos ventas completas (una online, una offline
> con QR) para encontrar errores. Se encontraron y corrigieron 8 bugs
> reales, incluyendo uno crítico que rompía el login (Firestore guarda
> `activo` como booleano y el código esperaba un entero, como en SQLite).
> Aun así, **la primera vez que corras `flutter run` puede aparecer algún
> error menor de compilación** que no se pudo detectar sin el compilador
> real — si pasa, mandame el mensaje de error exacto y lo arreglamos.

Lo que ya funciona de punta a punta:
- El vendedor busca productos, arma una venta y toca "FINALIZAR VENTA".
- La venta se guarda en SQLite con número correlativo automático.
- Se encola el cambio y, apenas hay internet, se sube sola a Firestore
  (`SyncService`, sin que el vendedor tenga que hacer nada).
- En **otro celular**, la pantalla de caja muestra esa venta en tiempo
  real (stream directo de Firestore) apenas se sincroniza.
- Login real con Firebase Auth: según el rol del usuario (guardado en
  Firestore), la app entra directo a la pantalla de Vendedor, Caja o
  Administrador.
- La caja puede tocar una venta, elegir método de pago (Efectivo/
  Transferencia/Débito/Crédito) y cobrar: esto descuenta stock
  automáticamente, marca la venta como cobrada, la sincroniza, e
  imprime el ticket en una impresora térmica Bluetooth (58 u 80mm).
- Si falla la sincronización por red, la caja puede escanear el QR de
  respaldo que generó el vendedor y reconstruir la venta completa sin
  depender de conexión (incluso el cobro posterior de esa venta
  sincroniza correctamente al mismo documento, sin duplicarlo).
- **Administración**: alta/baja/edición de productos, stock (ingreso de
  mercadería, ajuste manual, indicador de stock bajo), estadísticas
  (día/semana/mes, facturación, promedio, gráfico de productos más
  vendidos, ventas por vendedor), historial con búsqueda y filtro por
  fecha, y gestión de clientes — todo con datos reales sincronizados
  contra Firestore.

Lo que falta (con `// TODO` marcado en el código):
- **Fase 5 (extras):** sonido, vibración al confirmar venta, exportación
  de historial a Excel/PDF, backups automáticos, reimpresión de tickets,
  alta de usuarios desde la app (hoy requiere Firebase Console porque
  el SDK cliente no permite crear otro usuario sin cerrar la sesión del
  admin — necesita una Cloud Function), notificaciones push de stock bajo.

## Estructura de carpetas

```
lib/
  core/            -> constantes, tema, errores, utilidades, servicios
                       transversales (sync, QR, impresión, conectividad),
                       inyección de dependencias (Riverpod)
  domain/          -> entidades puras, contratos de repositorios, casos de uso
  data/            -> modelos (serialización), datasources (local/remote),
                       implementaciones de repositorios
  presentation/    -> pantallas y widgets por módulo (vendedor, caja, admin,
                       auth, shared)
firestore.rules   -> reglas de seguridad de Firestore de referencia
```

## Requisitos previos

- Flutter 3.22+ (`flutter --version`)
- Android Studio o VS Code con plugin de Flutter
- Un celular Android con **modo desarrollador** y **depuración USB**
  activados (para probar la sincronización entre vendedor y caja
  necesitás dos dispositivos: dos celulares, o un celular + un emulador)
- Cuenta de Google (para crear el proyecto de Firebase)
- Node.js (para instalar Firebase CLI)
- (Opcional para probar impresión real) una impresora térmica Bluetooth
  de 58mm u 80mm

## 1. Instalar dependencias

```bash
cd hortalizas_pos
flutter pub get
```

## 2. Generar los proyectos nativos (Android/iOS)

```bash
flutter create .
```

## 3. Permisos de Android (cámara y Bluetooth)

Agregá estos permisos en `android/app/src/main/AndroidManifest.xml`,
dentro de la etiqueta `<manifest>` (antes de `<application>`):

```xml
<!-- Cámara: para escanear el QR de respaldo -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Bluetooth: para la impresora térmica -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

(`ACCESS_FINE_LOCATION` lo pide Android para poder listar dispositivos
Bluetooth en versiones viejas; la app no usa la ubicación para nada
más). Android va a pedir estos permisos en tiempo de ejecución la
primera vez que se use la cámara o el Bluetooth — hay que aceptarlos.

## 4. Configurar Firebase (paso a paso)

1. Andá a [console.firebase.google.com](https://console.firebase.google.com)
   y creá un proyecto nuevo (ej: "hortalizas-pos").
2. Dentro del proyecto, activá:
   - **Firestore Database** (modo producción, región `southamerica-east1`
     o la más cercana).
   - **Authentication** → método "Correo electrónico/contraseña".
3. Instalá Firebase CLI y FlutterFire CLI:
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```
4. Iniciá sesión y conectá el proyecto:
   ```bash
   firebase login
   flutterfire configure
   ```
   Elegí el proyecto creado en el paso 1. Esto genera automáticamente
   `lib/firebase_options.dart` (que `main.dart` ya está esperando),
   `android/app/google-services.json` e
   `ios/Runner/GoogleService-Info.plist`.
5. Publicá las reglas de seguridad incluidas en `firestore.rules`:
   ```bash
   firebase deploy --only firestore:rules
   ```
   (o pegalas manualmente en Firebase Console → Firestore → Reglas).

## 5. Crear usuarios de prueba (uno por rol)

Como crear usuarios desde la app queda para la Fase 4 (requiere Cloud
Functions para no desloguear al admin), por ahora se crean a mano:

1. Firebase Console → **Authentication** → "Agregar usuario" → creá:
   - `vendedor@test.com` / una contraseña
   - `cajero@test.com` / una contraseña
   - (opcional) `admin@test.com` / una contraseña
2. Copiá el **UID** que le asignó Firebase a cada usuario (aparece en
   la lista de Authentication).
3. Firebase Console → **Firestore Database** → creá la colección
   `usuarios` → un documento **con ID = ese UID** (no un ID random) →
   con estos campos:
   ```
   nombre: "Vendedor Test"       (string)
   email: "vendedor@test.com"    (string)
   rol: "vendedor"               (string, exactamente: vendedor | cajero | administrador)
   activo: true                  (boolean)
   ```
4. Repetí para el usuario cajero (`rol: "cajero"`) y admin si querés.

## 6. Probar la app en el celular

1. Conectá el celular por USB con depuración habilitada (o abrí un
   emulador desde Android Studio).
2. Verificá que Flutter lo detecta:
   ```bash
   flutter devices
   ```
3. Instalá y corré la app:
   ```bash
   flutter run -d <device_id>
   ```
   (si solo hay un dispositivo conectado, alcanza con `flutter run`).
4. En la pantalla de login, entrá con `vendedor@test.com`.
5. Armá una venta (buscá "Papa", cantidad, precio total, Agregar) y
   tocá **FINALIZAR VENTA**. Va a aparecer el QR de respaldo y la venta
   queda guardada.
6. En **otro dispositivo** (otro celular o un emulador corriendo en
   paralelo), corré la misma app y entrá con `cajero@test.com`. La
   venta que acabás de crear en el primer celular debería aparecer sola
   en la lista de "Ventas pendientes" en unos segundos.
7. Tocá la venta, elegí un método de pago y tocá **COBRAR E IMPRIMIR**.
   Si no tenés una impresora Bluetooth emparejada, vas a ver un aviso
   de que no se pudo imprimir — la venta igual queda cobrada y el
   stock descontado correctamente.
8. Para probar el respaldo por QR: cortá el Wi-Fi/datos del celular del
   vendedor *después* de generar el QR (antes de que sincronice), y en
   el celular de caja tocá el ícono de escanear QR (arriba a la
   derecha) y apuntá a la pantalla del vendedor.
9. Para instalar el APK directamente en el celular sin cable (una vez
   compilado):
   ```bash
   flutter build apk --release
   ```
   El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.
   Pasalo al celular (por WhatsApp, Drive, USB, etc.), abrilo desde el
   explorador de archivos del celular e instalalo (puede pedir permitir
   "instalar apps de origen desconocido" la primera vez).

### Si la venta no aparece en el otro celular
- Revisá que ambos dispositivos tengan internet.
- Fijate en la consola de `flutter run` del vendedor si hay errores al
  sincronizar (buscá excepciones de Firestore).
- Confirmá que las reglas de Firestore ya están publicadas (paso 4.5).
- Confirmá que el documento del usuario en Firestore tiene el `rol`
  escrito exactamente como `vendedor` o `cajero` (en minúscula).
- **La primera vez** que la pantalla de caja intenta leer "ventas
  pendientes", Firestore puede pedir crear un índice compuesto (la
  consulta filtra por `estado` y ordena por `fecha` a la vez). Si ves un
  error mencionando "index" o "requires an index" en la pantalla de
  caja, abrí el link que trae ese mismo mensaje de error — te lleva
  directo a Firebase Console con el índice pre-cargado, solo hay que
  tocar "Crear". Tarda 1-2 minutos en activarse.

### Si la impresora no conecta
- Emparejala primero desde la configuración de Bluetooth del celular
  (Android), no desde la app.
- Aceptá los permisos de Bluetooth cuando la app los pida.
- Revisá que sea compatible con ESC/POS (la gran mayoría de impresoras
  térmicas de 58/80mm lo son).

## 7. Mantenimiento del proyecto

- **Agregar una dependencia nueva:** agregarla en `pubspec.yaml` y correr
  `flutter pub get`.
- **Cambiar el esquema de SQLite:** modificar
  `lib/data/datasources/local/database_helper.dart`, incrementar la
  versión (`version:`) y agregar lógica en `onUpgrade`.
- **Agregar un módulo nuevo:** seguir el mismo patrón de carpetas
  (`domain/entities`, `domain/repositories`, `domain/usecases`,
  `data/models`, `data/datasources`, `data/repositories`,
  `presentation/<modulo>`) y registrar los providers en
  `lib/core/di/providers.dart`.
- **Crear usuarios nuevos:** por ahora a mano en Firebase Console
  (ver paso 5). Automatizarlo es parte de la Fase 4.
- **Nombre del comercio en el ticket:** cambiar
  `AppConstants.nombreComercio` en
  `lib/core/constants/app_constants.dart` (en Fase 4 esto pasa a ser
  configurable desde la app).

## Próximo paso sugerido

**Fase 5**: sonido y vibración al confirmar una venta, exportación de
historial a Excel/PDF, backups automáticos, reimpresión de tickets
desde el historial, y una Cloud Function para poder dar de alta
usuarios nuevos directamente desde la app (sin pasar por Firebase
Console).
