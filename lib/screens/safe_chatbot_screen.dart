import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../services/safe_chatbot_service.dart';

class SafeChatbotScreen extends StatefulWidget {
  const SafeChatbotScreen({super.key});

  @override
  State<SafeChatbotScreen> createState() => _SafeChatbotScreenState();
}

class _SafeChatbotScreenState extends State<SafeChatbotScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _isTyping = false;
  List<String> _suggestions = const [
    'Buat laporan',
    'Laporan saya',
    'Voting laporan',
    'Tombol SOS',
    'Lokasi & peta',
    'Tambah Safe Friend',
    'Bagikan lokasi',
    'Login & akun',
  ];
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Aku bisa bantu kamu menemukan fitur SafeZone dan menjelaskan cara pakainya. Mulai dari topik di bawah atau tulis pertanyaanmu.',
      fromUser: false,
      isWelcome: true,
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  _ChatReply _answerFor(String question) {
    final text = question.toLowerCase();
    if (_hasAny(text, ['sos', 'darurat', 'bahaya', 'panik'])) {
      return const _ChatReply(
        'Cara memakai SOS:\n'
        '1. Tekan tombol SOS merah di tengah navigasi bawah.\n'
        '2. Ikuti pilihan bantuan yang muncul dan periksa kembali sebelum mengirim.\n'
        '3. Pastikan izin lokasi aktif agar lokasi dapat disertakan bila diminta.\n\n'
        'Kalau kamu sedang dalam bahaya langsung, segera hubungi layanan darurat setempat. SafeBot bukan layanan darurat dan tidak mengirim bantuan secara otomatis.',
        suggestions: ['Nomor penting', 'Izin lokasi', 'Cara pakai peta'],
      );
    }
    if (_hasAny(
        text, ['vote', 'voting', 'verifikasi', 'hoax', 'hoaks', 'beneran'])) {
      return const _ChatReply(
        'Di detail laporan, pilih “Beneran Ada” untuk mengonfirmasi atau “Hoax Nih” untuk menandai laporan tidak benar. Satu akun hanya dapat memberi satu suara pada satu laporan. Pemilik laporan tidak dapat memvote laporannya sendiri; minta warga lain meninjau.\n\n'
        'Gunakan suara berdasarkan informasi yang kamu ketahui, bukan sekadar menebak.',
        suggestions: ['Buat laporan', 'Laporan saya', 'Diskusi laporan'],
      );
    }
    if (_hasAny(text, ['lapor', 'kejadian', 'laporan', 'report'])) {
      if (_hasAny(
          text, ['status', 'saya', 'punya', 'milik', 'terkirim', 'lihat'])) {
        return const _ChatReply(
          'Untuk membuka laporanmu, masuk ke daftar laporan lalu pilih salah satu kartu untuk melihat detail, lokasi, media, dan status yang tersedia. Jika belum muncul, periksa koneksi internet dan pastikan kamu sedang memakai akun yang sama dengan akun pembuat laporan.\n\n'
          'Status verifikasi komunitas bukan jaminan bahwa kondisi di lokasi sudah aman.',
          suggestions: ['Cara membuat laporan', 'Voting laporan', 'Notifikasi'],
        );
      }
      return const _ChatReply(
        'Untuk mengirim laporan kejadian:\n'
        '1. Buka tab Lapor pada navigasi bawah.\n'
        '2. Pilih kategori yang paling sesuai, lalu tulis kronologi singkat dan jelas.\n'
        '3. Periksa titik lokasi; aktifkan izin lokasi atau sesuaikan titik pada peta bila perlu.\n'
        '4. Tambahkan foto/video jika membantu dan tidak membahayakanmu.\n'
        '5. Tinjau kembali informasinya, lalu kirim.\n\n'
        'Hindari mencantumkan data pribadi orang lain. Jika unggah media gagal, cek koneksi dan coba lagi.',
        suggestions: ['Laporan saya', 'Voting laporan', 'Lokasi laporan'],
      );
    }
    if (_hasAny(text, ['friend', 'teman', 'qr', 'kode qr', 'scan', 'pindai'])) {
      if (_hasAny(text, ['lokasi', 'bagikan', 'sharing', 'berbagi', 'live'])) {
        return const _ChatReply(
          'Berbagi lokasi Safe Friend memerlukan persetujuan dan tindakan dari kedua pihak. Tambahkan teman lebih dulu, tunggu permintaan diterima, lalu aktifkan Berbagi lokasi. Pastikan izin GPS diberikan. Kamu bisa mematikan berbagi kapan saja dari halaman Safe Friend.\n\n'
          'Bagikan lokasi hanya kepada orang yang kamu percaya.',
          suggestions: ['Tambah Safe Friend', 'QR saya', 'Izin lokasi'],
        );
      }
      return const _ChatReply(
        'Menambahkan Safe Friend:\n'
        '1. Buka Menu lalu pilih Safe Friend.\n'
        '2. Tampilkan QR milikmu agar teman dapat memindainya, atau tekan pindai untuk membaca QR teman.\n'
        '3. Tinjau permintaan pertemanan dan pastikan identitasnya sebelum menerima.\n\n'
        'QR digunakan untuk mengirim permintaan; lokasi tidak otomatis dibagikan. Berbagi lokasi perlu diaktifkan secara terpisah.',
        suggestions: ['QR saya', 'Pindai QR teman', 'Bagikan lokasi'],
      );
    }
    if (_hasAny(text, ['lokasi', 'peta', 'map', 'gps', 'sekitar', 'rute'])) {
      return const _ChatReply(
        'Untuk melihat lokasimu, ketuk lokasi di bawah sapaan pada Home atau buka Peta. Jika titik lokasi belum muncul, aktifkan Location/GPS di ponsel, izinkan SafeZone memakai lokasi, lalu coba muat ulang.\n\n'
        'Peta dan rute membantu membaca informasi sekitar, tetapi tidak menjamin suatu jalan aman. Tetap perhatikan kondisi nyata dan gunakan penilaianmu.',
        suggestions: ['Izin lokasi', 'Safe Friend', 'Buat laporan'],
      );
    }
    if (_hasAny(text, [
      'login',
      'masuk',
      'akun',
      'password',
      'sandi',
      'daftar',
      'register',
      'google'
    ])) {
      if (_hasAny(text, ['lupa', 'reset', 'password', 'sandi'])) {
        return const _ChatReply(
          'Di halaman Masuk, pilih “Lupa password?” lalu masukkan email akunmu. Buka email reset yang diterima dan ikuti tautannya. Periksa folder spam jika email belum terlihat. Jangan bagikan kata sandi atau tautan reset kepada siapa pun.',
          suggestions: [
            'Cara daftar',
            'Masuk dengan Google',
            'Tidak bisa masuk'
          ],
        );
      }
      return const _ChatReply(
        'Gunakan email dan kata sandi yang terdaftar, atau pilih masuk dengan Google bila akunmu terhubung. Untuk membuat akun baru, pilih Daftar dan isi data yang diminta. Jika sesi keluar, masuk lagi dengan metode yang sama.\n\n'
        'Jangan kirim kata sandi, kode verifikasi, atau data sensitif lewat chat.',
        suggestions: ['Lupa password', 'Cara daftar', 'Tidak bisa masuk'],
      );
    }
    if (_hasAny(
        text, ['notif', 'pemberitahuan', 'notice', 'lonceng', 'alert'])) {
      return const _ChatReply(
        'Ketuk ikon lonceng untuk membuka pembaruan laporan. Pilih satu notifikasi untuk menuju detail laporan terkait. Kalau pembaruan belum tampak, periksa koneksi internet dan izin notifikasi SafeZone di pengaturan ponsel.',
        suggestions: ['Laporan saya', 'Voting laporan', 'Izin notifikasi'],
      );
    }
    if (_hasAny(text, [
      'nomor penting',
      'nomor darurat',
      'telepon darurat',
      'ambulans',
      'polisi'
    ])) {
      return const _ChatReply(
        'Buka layanan Nomor Penting dari Home untuk melihat pilihan kontak darurat yang tersedia. Pastikan nomor dan wilayah layanan sesuai dengan lokasimu. Jika keadaan mendesak, hubungi layanan darurat resmi secara langsung.',
        suggestions: ['Tombol SOS', 'Lokasi & peta', 'Cara membuat laporan'],
      );
    }
    if (_hasAny(text, ['bantuan', 'help', 'fitur', 'apa aja', 'bisa apa'])) {
      return const _ChatReply(
        'Aku bisa bantu panduan tentang:\n'
        '• Membuat dan membuka laporan\n'
        '• Voting dan diskusi laporan\n'
        '• SOS dan nomor penting\n'
        '• Lokasi, peta, dan rute\n'
        '• Safe Friend, QR, dan berbagi lokasi\n'
        '• Login, akun, dan notifikasi\n\n'
        'Pilih topik dari tombol di bawah atau tulis pertanyaanmu. Aku hanya memberi panduan; aku tidak bisa melihat lokasi, akun, atau status laporanmu.',
        suggestions: [
          'Buat laporan',
          'Tombol SOS',
          'Lokasi & peta',
          'Tambah Safe Friend'
        ],
      );
    }
    return const _ChatReply(
      'Aku belum menemukan panduan yang cocok untuk pertanyaan itu. Coba tulis lebih spesifik—misalnya “cara pindai QR teman”, “lokasi tidak muncul”, atau “cara vote laporan”.',
      suggestions: [
        'Buat laporan',
        'Voting laporan',
        'Lokasi & peta',
        'Tambah Safe Friend'
      ],
    );
  }

  bool _hasAny(String text, List<String> keywords) =>
      keywords.any(text.contains);

  Future<void> _send([String? suggestion]) async {
    if (_isTyping) return;
    final question = (suggestion ?? _input.text).trim();
    if (question.isEmpty) return;
    _input.clear();
    final fallback = _answerFor(question);
    setState(() {
      _messages.add(_ChatMessage(text: question, fromUser: true));
      _suggestions = fallback.suggestions;
      _isTyping = true;
    });
    _scrollToLatest();

    final recentMessages = _messages.length > 12
        ? _messages.sublist(_messages.length - 12)
        : List<_ChatMessage>.of(_messages);
    String answer;
    try {
      answer = await SafeChatbotService.sendMessage(
        recentMessages
            .map((message) => <String, String>{
                  'role': message.fromUser ? 'user' : 'assistant',
                  'content': message.text,
                })
            .toList(growable: false),
      );
    } on SafeChatbotRateLimitException catch (error) {
      answer = error.message;
    } catch (error) {
      debugPrint('SafeBot AI unavailable: $error');
      answer =
          'AI SafeBot belum tersambung saat ini. Ini panduan cepatnya dulu:\n\n${fallback.text}';
    }

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: answer, fromUser: false));
      _isTyping = false;
    });
    _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.minScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: AppColors.red, size: 23),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SafeBot',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                Text('PANDUAN SAFEZONE',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text3,
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E5),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.cream2.withValues(alpha: .7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: AppColors.red, size: 17),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Panduan aplikasi, bukan layanan darurat. Untuk bantuan segera, gunakan SOS.',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text2, fontSize: 10, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == 0) {
                    return const _TypingIndicator();
                  }
                  final messageIndex = index - (_isTyping ? 1 : 0);
                  final message =
                      _messages[_messages.length - 1 - messageIndex];
                  return _MessageBubble(message: message);
                },
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _SuggestionChip(
                  label: _suggestions[index],
                  onPressed: () => _send(_suggestions[index]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Tulis pertanyaan…',
                        hintStyle: GoogleFonts.plusJakartaSans(
                            color: AppColors.text3, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide:
                                const BorderSide(color: AppColors.cream2)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide:
                                const BorderSide(color: AppColors.cream2)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                                color: AppColors.red, width: 1.4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isTyping ? null : () => _send(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isTyping
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 21),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final bool isWelcome;

  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.isWelcome = false,
  });
}

class _ChatReply {
  final String text;
  final List<String> suggestions;

  const _ChatReply(this.text, {this.suggestions = const []});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isWelcome) return _WelcomeCard(text: message.text);
    final fromUser = message.fromUser;
    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .79),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: fromUser ? AppColors.red : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(19),
          topRight: const Radius.circular(19),
          bottomLeft: Radius.circular(fromUser ? 19 : 6),
          bottomRight: Radius.circular(fromUser ? 6 : 19),
        ),
        border: fromUser ? null : Border.all(color: AppColors.cream2),
        boxShadow: fromUser
            ? null
            : [
                BoxShadow(
                    color: AppColors.text.withValues(alpha: .035),
                    blurRadius: 9,
                    offset: const Offset(0, 3))
              ],
      ),
      child: fromUser
          ? Text(message.text,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontSize: 13, height: 1.5))
          : _FormattedAssistantAnswer(message.text),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromUser) ...[
            const _BotAvatar(size: 27),
            const SizedBox(width: 8),
          ],
          bubble,
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String text;
  const _WelcomeCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cream2),
          boxShadow: [
            BoxShadow(
                color: AppColors.text.withValues(alpha: .045),
                blurRadius: 18,
                offset: const Offset(0, 7))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const _BotAvatar(size: 38),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Teman panduan SafeZone',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: AppColors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('Siap membantu',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.text3,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
            ]),
            const SizedBox(height: 15),
            Text('Halo, ada yang bisa kubantu?',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25)),
            const SizedBox(height: 6),
            Text(text,
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text2, fontSize: 12, height: 1.55)),
          ],
        ),
      );
}

class _BotAvatar extends StatelessWidget {
  final double size;
  const _BotAvatar({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: AppColors.redLight,
            borderRadius: BorderRadius.circular(size * .34)),
        child: Icon(Icons.support_agent_rounded,
            color: AppColors.red, size: size * .58),
      );
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SuggestionChip({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => ActionChip(
        onPressed: onPressed,
        avatar: const Icon(Icons.arrow_outward_rounded,
            size: 13, color: AppColors.red),
        label: Text(label,
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.text2,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.cream2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const _BotAvatar(size: 27),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.cream2),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(6))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                        color: AppColors.text3, shape: BoxShape.circle)),
              ],
              const SizedBox(width: 8),
              Text('SafeBot sedang menyusun jawaban',
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text3,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

class _FormattedAssistantAnswer extends StatelessWidget {
  final String text;

  const _FormattedAssistantAnswer(this.text);

  static final _numberedLine = RegExp(r'^(\s*)(\d+[.)])\s+(.*)$');
  static final _bulletLine = RegExp(r'^(\s*)[-*•]\s+(.*)$');
  static final _headingLine = RegExp(r'^#{1,6}\s+');
  static final _inlineMarkup = RegExp(r'(\*\*.*?\*\*|__.*?__|`[^`]+`)');

  TextStyle _baseStyle(BuildContext context) => GoogleFonts.plusJakartaSans(
        color: AppColors.text,
        fontSize: 13,
        height: 1.45,
      );

  List<InlineSpan> _spans(String value, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlineMarkup.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      final markup = match.group(0)!;
      if (markup.startsWith('**') || markup.startsWith('__')) {
        spans.add(TextSpan(
          text: markup.substring(2, markup.length - 2),
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
      } else {
        spans.add(TextSpan(
          text: markup.substring(1, markup.length - 1),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: AppColors.bg,
          ),
        ));
      }
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    // Never expose raw Markdown markers if a model returns malformed markup.
    return spans
        .map((span) => span is TextSpan
            ? TextSpan(
                text: span.text?.replaceAll('*', '').replaceAll('`', ''),
                style: span.style,
                children: span.children,
              )
            : span)
        .toList(growable: false);
  }

  Widget _line(String value, TextStyle style, {bool bold = false}) {
    final content = value.replaceFirst(_headingLine, '');
    final spans = _spans(content, style);
    return Text.rich(
      TextSpan(
        style: bold ? style.copyWith(fontWeight: FontWeight.w700) : style,
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _baseStyle(context);
    final children = <Widget>[];

    for (final rawLine in text.replaceAll('\r', '').split('\n')) {
      if (rawLine.trim().isEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 7));
        continue;
      }

      final numbered = _numberedLine.firstMatch(rawLine);
      if (numbered != null) {
        final indent = numbered.group(1)!.length * 8.0;
        children.add(Padding(
          padding: EdgeInsets.only(left: indent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 23,
                child: Text(
                  numbered.group(2)!,
                  style: style.copyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(child: _line(numbered.group(3)!, style)),
            ],
          ),
        ));
        continue;
      }

      final bullet = _bulletLine.firstMatch(rawLine);
      if (bullet != null) {
        final indent = bullet.group(1)!.length * 8.0;
        children.add(Padding(
          padding: EdgeInsets.only(left: indent + 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: Text('•', style: style.copyWith(color: AppColors.red)),
              ),
              Expanded(child: _line(bullet.group(2)!, style)),
            ],
          ),
        ));
        continue;
      }

      final isHeading = _headingLine.hasMatch(rawLine) ||
          (rawLine.startsWith('**') && rawLine.endsWith('**'));
      children.add(_line(rawLine, style, bold: isHeading));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
