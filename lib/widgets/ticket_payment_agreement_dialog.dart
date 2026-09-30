import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TicketPaymentAgreementDialog extends StatefulWidget {
  final double ticketPrice;

  const TicketPaymentAgreementDialog({super.key, required this.ticketPrice});

  @override
  State<TicketPaymentAgreementDialog> createState() =>
      _TicketPaymentAgreementDialogState();
}

class _TicketPaymentAgreementDialogState
    extends State<TicketPaymentAgreementDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat.currency(
      locale: 'en_GB',
      symbol: '£',
    ).format(widget.ticketPrice);

    return AlertDialog(
      title: const Text('Ticket payment agreement'),
      content: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _agreed,
        onChanged: (value) => setState(() => _agreed = value ?? false),
        title: Text('I agree to pay $price for my ticket allocation.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Agree and draw'),
        ),
      ],
    );
  }
}
