import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/whatsapp_helper.dart';

/// Botón que abre WhatsApp directo en el chat de este teléfono. No
/// dibuja nada si el teléfono está vacío, así que se puede usar sin
/// envolverlo en un `if` en cada pantalla.
class WhatsappButton extends StatelessWidget {
  final String telefono;
  final double size;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  const WhatsappButton({
    super.key,
    required this.telefono,
    this.size = 20,
    this.padding,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final link = WhatsappHelper.linkChat(telefono);
    if (link == null) return const SizedBox.shrink();

    return IconButton(
      icon: FaIcon(FontAwesomeIcons.whatsapp, size: size, color: const Color(0xFF25D366)),
      tooltip: 'Abrir WhatsApp',
      padding: padding,
      constraints: constraints,
      onPressed: () async {
        final abierto = await launchUrl(link, mode: LaunchMode.externalApplication);
        if (!abierto && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp')),
          );
        }
      },
    );
  }
}
