part of '../settings_screen.dart';

class _SosSettingsCard extends ConsumerStatefulWidget {
  const _SosSettingsCard();

  @override
  ConsumerState<_SosSettingsCard> createState() => _SosSettingsCardState();
}

class _SosSettingsCardState extends ConsumerState<_SosSettingsCard> {
  late final TextEditingController _templateCtrl;

  @override
  void initState() {
    super.initState();
    _templateCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(sosSettingsProvider);
    final channels =
        ref.watch(channelsProvider).where((c) => !c.isEmpty).toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    final contacts = ref.watch(contactsProvider);

    if (_templateCtrl.text != settings.messageTemplate) {
      _templateCtrl.text = settings.messageTemplate;
      _templateCtrl.selection = TextSelection.collapsed(
        offset: _templateCtrl.text.length,
      );
    }

    String channelLabel(ChannelInfo c) {
      final name = c.name.trim().isEmpty ? '(sem nome)' : c.name.trim();
      return '#${c.index} $name';
    }

    Contact? selectedContact;
    for (final c in contacts) {
      if (base64Encode(c.publicKey) == settings.contactKeyBase64) {
        selectedContact = c;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sos, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'SOS',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configura o destino e a mensagem de emergência. Usa {gps} no texto para inserir coordenadas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SosTargetType>(
              key: ValueKey('sos_target_${settings.targetType.name}'),
              initialValue: settings.targetType,
              decoration: const InputDecoration(
                labelText: 'Destino SOS',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: SosTargetType.channel,
                  child: Text('Canal'),
                ),
                DropdownMenuItem(
                  value: SosTargetType.contact,
                  child: Text('Contacto privado'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(sosSettingsProvider.notifier).setTargetType(v);
                }
              },
            ),
            const SizedBox(height: 10),
            if (settings.targetType == SosTargetType.channel)
              DropdownButtonFormField<int>(
                key: ValueKey('sos_channel_${settings.channelIndex}'),
                initialValue: settings.channelIndex,
                decoration: const InputDecoration(
                  labelText: 'Canal de envio',
                  border: OutlineInputBorder(),
                ),
                items: [
                  if (channels.isEmpty)
                    const DropdownMenuItem(value: 0, child: Text('#0 Geral')),
                  ...channels.map(
                    (c) => DropdownMenuItem<int>(
                      value: c.index,
                      child: Text(channelLabel(c)),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref.read(sosSettingsProvider.notifier).setChannelIndex(v);
                  }
                },
              )
            else
              InkWell(
                onTap:
                    contacts.isEmpty
                        ? null
                        : () => _pickSosContact(context, contacts, settings),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Contacto de destino',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedContact?.displayName ??
                              (contacts.isEmpty
                                  ? 'Sem contactos disponíveis'
                                  : 'Toque para procurar contacto'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedContact != null)
                        IconButton(
                          tooltip: 'Limpar contacto',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed:
                              () => ref
                                  .read(sosSettingsProvider.notifier)
                                  .setContactKey(null),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _templateCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mensagem SOS',
                hintText: 'Ex.: SOS - preciso de ajuda! {gps}',
                border: OutlineInputBorder(),
              ),
              onChanged:
                  (v) => ref
                      .read(sosSettingsProvider.notifier)
                      .setMessageTemplate(v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir coordenadas GPS do telemóvel'),
              subtitle: const Text(
                'Se não houver GPS/permissão, a mensagem é enviada sem coordenadas.',
              ),
              value: settings.includeGps,
              onChanged:
                  (v) =>
                      ref.read(sosSettingsProvider.notifier).setIncludeGps(v),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.sos),
                label: const Text('Enviar SOS agora'),
                onPressed: () async {
                  final result =
                      await ref.read(sosServiceProvider).sendConfiguredSos();
                  if (!context.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  switch (result.outcome) {
                    case SosSendOutcome.sent:
                      messenger.showSnackBar(
                        const SnackBar(content: Text('SOS enviado')),
                      );
                    case SosSendOutcome.notConnected:
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Rádio não ligado')),
                      );
                    case SosSendOutcome.missingContact:
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Contacto SOS não configurado/encontrado',
                          ),
                        ),
                      );
                    case SosSendOutcome.permissionDenied:
                    case SosSendOutcome.locationDisabled:
                    case SosSendOutcome.failed:
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            result.detail?.isNotEmpty == true
                                ? 'Falha SOS: ${result.detail}'
                                : 'Falha ao enviar SOS',
                          ),
                        ),
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSosContact(
    BuildContext context,
    List<Contact> contacts,
    SosSettings settings,
  ) async {
    final searchCtrl = TextEditingController();
    String query = '';

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final q = query.trim().toLowerCase();
            final filtered =
                contacts.where((c) {
                    if (q.isEmpty) return true;
                    return c.displayName.toLowerCase().contains(q) ||
                        c.shortId.toLowerCase().contains(q);
                  }).toList()
                  ..sort(
                    (a, b) => a.displayName.toLowerCase().compareTo(
                      b.displayName.toLowerCase(),
                    ),
                  );

            return AlertDialog(
              title: const Text('Procurar contacto SOS'),
              content: SizedBox(
                width: 420,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Nome ou ID curto',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setLocal(() => query = v),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child:
                            filtered.isEmpty
                                ? const Center(
                                  child: Text('Nenhum contacto encontrado'),
                                )
                                : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, i) {
                                    final c = filtered[i];
                                    final key = base64Encode(c.publicKey);
                                    final selected =
                                        key == settings.contactKeyBase64;
                                    return ListTile(
                                      dense: true,
                                      title: Text(c.displayName),
                                      subtitle: Text(c.shortId),
                                      trailing:
                                          selected
                                              ? const Icon(Icons.check)
                                              : null,
                                      onTap: () => Navigator.of(ctx).pop(key),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('__clear__'),
                  child: const Text('Limpar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    searchCtrl.dispose();
    if (!mounted) return;
    if (result == '__clear__') {
      await ref.read(sosSettingsProvider.notifier).setContactKey(null);
      return;
    }
    if (result != null) {
      await ref.read(sosSettingsProvider.notifier).setContactKey(result);
    }
  }
}
