// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:built_collection/built_collection.dart';

// Project imports:
import 'package:invoiceninja_flutter/data/models/e_invoice_model.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/redux/invoice/invoice_selectors.dart';
import 'package:invoiceninja_flutter/ui/app/entity_dropdown.dart';
import 'package:invoiceninja_flutter/ui/app/form_card.dart';
import 'package:invoiceninja_flutter/ui/app/forms/date_picker.dart';
import 'package:invoiceninja_flutter/ui/app/scrollable_listview.dart';
import 'package:invoiceninja_flutter/ui/invoice/edit/invoice_edit_e_invoice_vm.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';

class InvoiceEditEInvoice extends StatelessWidget {
  const InvoiceEditEInvoice({
    Key? key,
    required this.viewModel,
  }) : super(key: key);

  final EntityEditEInvoiceVM viewModel;

  @override
  Widget build(BuildContext context) {
    final invoice = viewModel.invoice!;

    if (invoice.entityType == EntityType.credit) {
      return _CreditEInvoiceForm(viewModel: viewModel);
    }

    return _InvoiceEInvoiceForm(viewModel: viewModel);
  }
}

class _InvoiceEInvoiceForm extends StatelessWidget {
  const _InvoiceEInvoiceForm({required this.viewModel});

  final EntityEditEInvoiceVM viewModel;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context)!;
    final invoice = viewModel.invoice!;
    final eInvoice = invoice.eInvoice;
    final eInvoiceInvoice = eInvoice.invoice ?? EInvoiceInvoiceEntity();
    final period = eInvoiceInvoice.invoicePeriod.isNotEmpty
        ? eInvoiceInvoice.invoicePeriod.first
        : EInvoiceInvoicePeriodEntity();
    final delivery = eInvoiceInvoice.delivery.isNotEmpty
        ? eInvoiceInvoice.delivery.first
        : EInvoiceDeliveryEntity();

    return ScrollableListView(
      children: <Widget>[
        FormCard(
          isLast: true,
          children: <Widget>[
            DatePicker(
              labelText: localization.startDate,
              selectedDate: period.startDate ?? '',
              onSelected: (date, _) {
                final updatedPeriod =
                    period.rebuild((b) => b..startDate = date);
                _updateInvoicePeriod(updatedPeriod, eInvoiceInvoice, eInvoice);
              },
            ),
            DatePicker(
              labelText: localization.endDate,
              selectedDate: period.endDate ?? '',
              onSelected: (date, _) {
                final updatedPeriod = period.rebuild((b) => b..endDate = date);
                _updateInvoicePeriod(updatedPeriod, eInvoiceInvoice, eInvoice);
              },
            ),
            if (invoice.entityType != EntityType.recurringInvoice)
              DatePicker(
                labelText: localization.actualDeliveryDate,
                selectedDate: delivery.actualDeliveryDate ?? '',
                onSelected: (date, _) {
                  final updatedDelivery =
                      delivery.rebuild((b) => b..actualDeliveryDate = date);
                  final updatedInvoice = eInvoiceInvoice.rebuild((b) => b
                    ..delivery.replace(
                        BuiltList<EInvoiceDeliveryEntity>([updatedDelivery])));
                  final updatedEInvoice = eInvoice.rebuild(
                      (b) => b..invoice.replace(updatedInvoice));
                  viewModel.onChanged!(invoice
                      .rebuild((b) => b..eInvoice.replace(updatedEInvoice)));
                },
              ),
          ],
        ),
      ],
    );
  }

  void _updateInvoicePeriod(EInvoiceInvoicePeriodEntity updatedPeriod,
      EInvoiceInvoiceEntity eInvoiceInvoice, EInvoiceEntity eInvoice) {
    final invoice = viewModel.invoice!;
    final updatedInvoice = eInvoiceInvoice.rebuild((b) => b
      ..invoicePeriod.replace(
          BuiltList<EInvoiceInvoicePeriodEntity>([updatedPeriod])));
    final updatedEInvoice =
        eInvoice.rebuild((b) => b..invoice.replace(updatedInvoice));
    viewModel
        .onChanged!(invoice.rebuild((b) => b..eInvoice.replace(updatedEInvoice)));
  }
}

class _CreditEInvoiceForm extends StatelessWidget {
  const _CreditEInvoiceForm({required this.viewModel});

  final EntityEditEInvoiceVM viewModel;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context)!;
    final state = viewModel.state!;
    final credit = viewModel.invoice!;
    final eInvoice = credit.eInvoice;
    final creditNote = eInvoice.creditNote ?? EInvoiceCreditNoteEntity();
    final billingRef = creditNote.billingReference.isNotEmpty
        ? creditNote.billingReference.first
        : EInvoiceBillingReferenceEntity();
    final docRef =
        billingRef.invoiceDocumentReference ?? EInvoiceDocumentReferenceEntity();

    String? invoiceId;
    if ((docRef.id ?? '').isNotEmpty) {
      for (final id in state.invoiceState.list) {
        final invoice = state.invoiceState.map[id];
        if (invoice != null && invoice.number == docRef.id) {
          invoiceId = invoice.id;
          break;
        }
      }
    }

    final invoiceIds = memoizedDropdownInvoiceList(
      state.invoiceState.map,
      state.clientState.map,
      state.vendorState.map,
      state.invoiceState.list,
      credit.clientId,
      state.userState.map,
      <String?>[],
      state.company.settings.recurringNumberPrefix,
    );

    return ScrollableListView(
      children: <Widget>[
        FormCard(
          isLast: true,
          children: <Widget>[
            EntityDropdown(
              entityType: EntityType.invoice,
              labelText: localization.invoice,
              entityId: invoiceId ?? '',
              entityList: invoiceIds,
              onSelected: (selectedInvoice) {
                final inv = selectedInvoice as InvoiceEntity?;
                final updatedDocRef = EInvoiceDocumentReferenceEntity().rebuild(
                    (b) => b
                      ..id = inv?.number ?? ''
                      ..issueDate = inv?.date ?? '');
                final updatedBillingRef =
                    EInvoiceBillingReferenceEntity().rebuild(
                        (b) => b..invoiceDocumentReference.replace(updatedDocRef));
                final updatedCreditNote = EInvoiceCreditNoteEntity().rebuild(
                    (b) => b
                      ..billingReference.replace(
                          BuiltList<EInvoiceBillingReferenceEntity>(
                              [updatedBillingRef])));
                final updatedEInvoice = eInvoice
                    .rebuild((b) => b..creditNote.replace(updatedCreditNote));
                viewModel.onChanged!(credit
                    .rebuild((b) => b..eInvoice.replace(updatedEInvoice)));
              },
            ),
          ],
        ),
      ],
    );
  }
}
