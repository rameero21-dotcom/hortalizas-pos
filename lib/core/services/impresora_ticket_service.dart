import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Maneja la impresión de tickets en la impresora térmica USB (POS80-CX,
/// y en general cualquier impresora ESC/POS ya instalada como impresora
/// de Windows).
///
/// En vez de usar el sistema normal de impresión de Windows (que
/// convierte todo a texto/gráfico genérico), esto manda los bytes
/// ESC/POS directo a la cola de impresión en modo "RAW" — así el ticket
/// puede tener negrita, tamaños de letra, y el QR nativo de la
/// impresora, en vez de limitarse a texto plano.
///
/// Requiere que la impresora YA esté agregada en Windows (en
/// "Impresoras y escáneres"), con cualquier driver — el modo RAW no usa
/// las capacidades del driver, así que alcanza con un driver genérico
/// tipo "Generic / Text Only".
class ImpresoraTicketService {
  /// Lista los nombres de las impresoras instaladas en Windows, para
  /// que el usuario elija cuál es la térmica (ver pantalla de
  /// configuración de impresora en Admin).
  static List<String> listarImpresoras() {
    if (!Platform.isWindows) return [];

    final pcbNeeded = calloc<DWORD>();
    final pcReturned = calloc<DWORD>();
    try {
      // Primera llamada: solo para saber cuántos bytes hacen falta.
      EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 4,
          nullptr, 0, pcbNeeded, pcReturned);

      final bytesNecesarios = pcbNeeded.value;
      if (bytesNecesarios == 0) return [];

      final buffer = calloc<BYTE>(bytesNecesarios);
      try {
        final ok = EnumPrinters(
            PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
            nullptr,
            4,
            buffer,
            bytesNecesarios,
            pcbNeeded,
            pcReturned);
        if (ok == 0) return [];

        final nombres = <String>[];
        final infoPtr = buffer.cast<PRINTER_INFO_4>();
        for (var i = 0; i < pcReturned.value; i++) {
          final info = (infoPtr + i).ref;
          if (info.pPrinterName != nullptr) {
            nombres.add(info.pPrinterName.toDartString());
          }
        }
        return nombres;
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
    }
  }

  /// Manda bytes ESC/POS crudos a la impresora indicada por nombre
  /// (tal cual aparece en "Impresoras y escáneres" de Windows).
  /// Devuelve true si el trabajo se mandó bien a la cola de impresión
  /// (no garantiza que haya salido papel físicamente: eso depende del
  /// hardware, si tiene papel, si está prendida, etc).
  static bool imprimirRaw(String nombreImpresora, List<int> bytes) {
    if (!Platform.isWindows) {
      throw UnsupportedError('La impresión térmica solo está disponible en Windows por ahora.');
    }

    final phPrinter = calloc<HANDLE>();
    final pPrinterName = nombreImpresora.toNativeUtf16();
    Pointer<Utf16>? pDocName;
    Pointer<Utf16>? pDatatype;
    Pointer<DOC_INFO_1>? docInfo;
    Pointer<Uint8>? pBytes;
    Pointer<DWORD>? pEscritos;

    try {
      final abierto = OpenPrinter(pPrinterName, phPrinter, nullptr);
      if (abierto == 0) return false;

      final hPrinter = phPrinter.value;
      try {
        pDocName = 'Ticket de venta'.toNativeUtf16();
        pDatatype = 'RAW'.toNativeUtf16();
        docInfo = calloc<DOC_INFO_1>();
        docInfo.ref
          ..pDocName = pDocName
          ..pOutputFile = nullptr
          ..pDatatype = pDatatype;

        final idTrabajo = StartDocPrinter(hPrinter, 1, docInfo.cast());
        if (idTrabajo == 0) return false;

        try {
          if (StartPagePrinter(hPrinter) == 0) return false;

          try {
            pBytes = calloc<Uint8>(bytes.length);
            for (var i = 0; i < bytes.length; i++) {
              pBytes[i] = bytes[i];
            }
            pEscritos = calloc<DWORD>();
            final escrito =
                WritePrinter(hPrinter, pBytes.cast(), bytes.length, pEscritos);
            return escrito != 0;
          } finally {
            EndPagePrinter(hPrinter);
          }
        } finally {
          EndDocPrinter(hPrinter);
        }
      } finally {
        ClosePrinter(hPrinter);
      }
    } finally {
      calloc.free(phPrinter);
      calloc.free(pPrinterName);
      if (pDocName != null) calloc.free(pDocName);
      if (pDatatype != null) calloc.free(pDatatype);
      if (docInfo != null) calloc.free(docInfo);
      if (pBytes != null) calloc.free(pBytes);
      if (pEscritos != null) calloc.free(pEscritos);
    }
  }
}
