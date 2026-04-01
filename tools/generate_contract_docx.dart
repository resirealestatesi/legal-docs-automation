// tools/generate_contract_docx.dart
// Ejecutar: dart run tools/generate_contract_docx.dart
//
// Genera el archivo contrato_arrendamiento.docx con placeholders

import 'dart:io';
import 'package:docx_creator/docx_creator.dart';

Future<void> main() async {
  final builder = DocxDocumentBuilder()
    ..section(
      pageSize: DocxPageSize.letter,
      orientation: DocxPageOrientation.portrait,
    )
    ..h2('CONTRATO DE ARRENDAMIENTO DE INMUEBLE')
    ..p('')
    ..p(
      'En la ciudad de {{CIUDAD}}, a los {{FECHA_INICIO}}, entre:',
      align: DocxAlign.left,
    )
    ..p('')
    ..p(
      'ARRENDADOR: {{NOMBRE_ARRENDADOR}}, portador(a) de la cédula de identidad No. {{CEDULA_ARRENDADOR}}, en adelante "EL ARRENDADOR".',
    )
    ..p('')
    ..p(
      'ARRENDATARIO: {{NOMBRE_ARRENDATARIO}}, portador(a) de la cédula de identidad No. {{CEDULA_ARRENDATARIO}}, en adelante "EL ARRENDATARIO".',
    )
    ..p('')
    ..p(
      'Se ha convenido celebrar el presente contrato de arrendamiento de inmueble, el cual se regirá por las siguientes cláusulas:',
    )
    ..p('')
    ..p(
      'PRIMERA - OBJETO: El ARRENDADOR entrega en arrendamiento al ARRENDATARIO el inmueble ubicado en {{DIRECCION_INMUEBLE}}, para uso habitacional.',
    )
    ..p('')
    ..p(
      'SEGUNDA - PLAZO: El presente contrato tendrá vigencia desde el {{FECHA_INICIO}} hasta el {{FECHA_FIN}}, pudiendo ser renovado de mutuo acuerdo entre las partes.',
    )
    ..p('')
    ..p(
      'TERCERA - RENTA MENSUAL: El ARRENDATARIO se obliga a pagar al ARRENDADOR la suma de {{MONTO_RENTA}} mensuales, pagaderos el día {{DIA_PAGO}} de cada mes.',
    )
    ..p('')
    ..p(
      'CUARTA - GARANTÍA: Al momento de la firma, el ARRENDATARIO entrega la suma de {{MONTO_GARANTIA}} como garantía de cumplimiento.',
    )
    ..p('')
    ..p('QUINTA - OBLIGACIONES DEL ARRENDATARIO:')
    ..p('a) Conservar el inmueble en buen estado.')
    ..p('b) No subarrendar sin autorización escrita.')
    ..p('c) Permitir las inspecciones del ARRENDADOR.')
    ..p('')
    ..p('SEXTA - OBLIGACIONES DEL ARRENDADOR:')
    ..p('a) Mantener el inmueble en condiciones habitables.')
    ..p('b) Respetar el plazo de duración del contrato.')
    ..p('')
    ..p(
      'En señal de conformidad, las partes firman el presente contrato.',
    )
    ..p('')
    ..p('FIRMA DEL ARRENDADOR                    FIRMA DEL ARRENDATARIO')
    ..p('')
    ..p('_________________________               _________________________')
    ..p('{{NOMBRE_ARRENDADOR}}                   {{NOMBRE_ARRENDATARIO}}')
    ..p('C.I.: {{CEDULA_ARRENDADOR}}             C.I.: {{CEDULA_ARRENDATARIO}}');

  final doc = builder.build();
  final outputPath = 'tools/contrato_arrendamiento.docx';
  await DocxExporter().exportToFile(doc, outputPath);

  print('Archivo generado: $outputPath');
  print('Tamaño: ${File(outputPath).lengthSync()} bytes');
}
