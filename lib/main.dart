import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  runApp(const ShahriarApp());
}

// ═══════════════════ ابزارها و ثابت‌ها ═══════════════════

const appName = 'ساختمان شهریار';
const waGroupUrl = 'https://chat.whatsapp.com/KrHMZ9QHMY481LMyk4rqKv?s=cl&p=a&mlu=4&ilr=4';
const baleGroupUrl = 'https://ble.ir/join/twF9MK8gGy';

class Store {
  static late final SharedPreferences prefs;
  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }
}

class C {
  static const bg = Color(0xFF0D1B2A);
  static const card = Color(0xFF16283F);
  static const card2 = Color(0xFF1C3350);
  static const gold = Color(0xFFF9C440);
  static const goldSoft = Color(0xFFFFE082);
  static const green = Color(0xFF2ECC8F);
  static const red = Color(0xFFFF5A79);
  static const amber = Color(0xFFFFB74D);
  static const blue = Color(0xFF29A9EB);
  static const teal = Color(0xFF26C6DA);
}

const _jMonths = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];
const _jWeekdays = ['شنبه', 'یک‌شنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه'];

final _faMap = {'0': '۰', '1': '۱', '2': '۲', '3': '۳', '4': '۴', '5': '۵', '6': '۶', '7': '۷', '8': '۸', '9': '۹'};
String toFa(String s) => s.replaceAllMapped(RegExp(r'\d'), (m) => _faMap[m.group(0)]!);
String faNum(num n) => toFa(NumberFormat('#,###').format(n));

String todayJalali() {
  final j = Jalali.now();
  return toFa('${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}');
}

String fullJalali() {
  final j = Jalali.now();
  return '${_jWeekdays[j.weekDay - 1]} ${toFa('${j.day}')} ${_jMonths[j.month - 1]} ${toFa('${j.year}')}';
}

Route _fadeRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Widget _logo({double size = 44}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: C.card2,
      border: Border.all(color: C.gold, width: 2),
      boxShadow: const [BoxShadow(color: Color(0x66F9C440), blurRadius: 18, offset: Offset(0, 6))],
    ),
    child: ClipOval(
      child: Image.asset(
        'assets/images/shahriar_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.apartment_rounded, size: size * .6, color: C.gold),
      ),
    ),
  );
}

// ═══════════════════ مدل‌ها ═══════════════════

class Member {
  String id, name, ownerPhone, tenantPhone;
  int monthlyCharge;
  int seasonalCharge;
  Member({
    required this.id,
    required this.name,
    required this.ownerPhone,
    required this.tenantPhone,
    this.monthlyCharge = 0,
    this.seasonalCharge = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner': ownerPhone,
        'tenant': tenantPhone,
        'monthly': monthlyCharge,
        'seasonal': seasonalCharge,
      };

  factory Member.fromMap(Map<String, dynamic> m) => Member(
        id: m['id'] as String,
        name: m['name'] as String,
        ownerPhone: (m['owner'] ?? '') as String,
        tenantPhone: (m['tenant'] ?? '') as String,
        monthlyCharge: (m['monthly'] as num?)?.toInt() ?? 0,
        seasonalCharge: (m['seasonal'] as num?)?.toInt() ?? 0,
      );
}

class Payment {
  String id, title, member, date;
  int amount;
  bool isIncome;
  int createdAt;
  Payment({required this.id, required this.title, required this.amount, required this.isIncome,
    required this.member, required this.date, required this.createdAt});

  Map<String, dynamic> toMap() =>
      {'id': id, 'title': title, 'amount': amount, 'income': isIncome, 'member': member, 'date': date, 'createdAt': createdAt};
  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
    id: m['id'] as String,
    title: m['title'] as String,
    amount: (m['amount'] as num).toInt(),
    isIncome: m['income'] == true,
    member: (m['member'] ?? '') as String,
    date: m['date'] as String,
    createdAt: (m['createdAt'] as num).toInt(),
  );
}

class Operation {
  String id, title, detail, date;
  int createdAt;
  Operation({required this.id, required this.title, required this.detail, required this.date, required this.createdAt});

  Map<String, dynamic> toMap() =>
      {'id': id, 'title': title, 'detail': detail, 'date': date, 'createdAt': createdAt};
  factory Operation.fromMap(Map<String, dynamic> m) => Operation(
    id: m['id'] as String,
    title: m['title'] as String,
    detail: (m['detail'] ?? '') as String,
    date: m['date'] as String,
    createdAt: (m['createdAt'] as num).toInt(),
  );
}

// ═══════════════════ اپلیکیشن ═══════════════════

class ShahriarApp extends StatelessWidget {
  const ShahriarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'BNazanin',
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: C.gold, brightness: Brightness.dark),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontFamily: 'BNazanin', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.card2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.gold, width: 1.4)),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.gold,
            foregroundColor: C.bg,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontFamily: 'BNazanin', fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: C.goldSoft,
            side: const BorderSide(color: C.gold),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: C.goldSoft)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: C.gold,
          foregroundColor: C.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.card2,
          contentTextStyle: TextStyle(fontFamily: 'BNazanin', color: Colors.white),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ═══════════════════ صفحه ورود ═══════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _hide = true;
  bool _residentMode = false;
  String _selectedUnit = '';
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _members = ((jsonDecode(Store.prefs.getString('members') ?? '[]') as List)
            .map((e) => Member.fromMap(Map<String, dynamic>.from(e))))
        .toList();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

  void _loginAdmin() {
    final pass = Store.prefs.getString('admin_pass') ?? '1234';
    if (_passCtrl.text == pass) {
      Navigator.of(context).pushReplacement(_fadeRoute(const HomeScreen(isAdmin: true)));
    } else {
      _snack('کد عبور نادرست است ❌');
    }
  }

  void _loginResident() {
    if (_members.isEmpty) {
      _snack('هنوز واحدی توسط مدیر ثبت نشده است');
      return;
    }
    if (_selectedUnit.isEmpty) {
      _snack('واحد خود را انتخاب کنید');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _snack('شماره تماس را وارد کنید');
      return;
    }
    Member? me;
    for (final m in _members) {
      if (m.name == _selectedUnit &&
          (m.ownerPhone.trim() == phone || m.tenantPhone.trim() == phone)) {
        me = m;
        break;
      }
    }
    if (me == null) {
      _snack('شماره تماس با واحد انتخابی مطابقت ندارد ❌');
      return;
    }
    Navigator.of(context).pushReplacement(
        _fadeRoute(HomeScreen(isAdmin: false, myMemberId: me.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF142A44), C.bg, Color(0xFF0A1420)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _logo(size: 110),
              const SizedBox(height: 20),
              const Text(appName,
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold, color: C.gold)),
              const Text('سیستم مدیریت ساختمان',
                  style: TextStyle(fontSize: 15, color: Colors.white70)),
              const SizedBox(height: 28),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('ورود مدیر'), icon: Icon(Icons.admin_panel_settings_rounded)),
                  ButtonSegment(value: true, label: Text('ورود ساکنین'), icon: Icon(Icons.person_rounded)),
                ],
                selected: {_residentMode},
                onSelectionChanged: (s) => setState(() => _residentMode = s.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: C.card,
                  selectedBackgroundColor: C.gold,
                  selectedForegroundColor: C.bg,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _residentMode ? _residentForm() : _adminForm(),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _adminForm() {
    return Column(key: const ValueKey('admin'), children: [
      TextField(
        controller: _passCtrl,
        obscureText: _hide,
        textAlign: TextAlign.center,
        onSubmitted: (_) => _loginAdmin(),
        decoration: InputDecoration(
          labelText: 'کد عبور مدیر',
          prefixIcon: const Icon(Icons.lock_rounded, color: C.goldSoft),
          suffixIcon: IconButton(
            icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: Colors.white54),
            onPressed: () => setState(() => _hide = !_hide),
          ),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loginAdmin,
          child: const Padding(padding: EdgeInsets.all(6), child: Text('ورود مدیر')),
        ),
      ),
      const SizedBox(height: 16),
      const Text('رمز پیش‌فرض: 1234', style: TextStyle(fontSize: 12, color: Colors.white38)),
    ]);
  }

  Widget _residentForm() {
    return Column(key: const ValueKey('resident'), children: [
      DropdownButtonFormField<String>(
        value: _selectedUnit.isEmpty ? null : _selectedUnit,
        isExpanded: true,
        dropdownColor: C.card2,
        decoration: const InputDecoration(
            labelText: 'انتخاب واحد',
            prefixIcon: Icon(Icons.door_front_door_rounded, color: C.goldSoft)),
        items: _members.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))).toList(),
        onChanged: (v) => setState(() => _selectedUnit = v ?? ''),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        textAlign: TextAlign.center,
        onSubmitted: (_) => _loginResident(),
        decoration: const InputDecoration(
          labelText: 'شماره تماس مالک یا مستأجر',
          prefixIcon: Icon(Icons.call_rounded, color: C.goldSoft),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loginResident,
          child: const Padding(padding: EdgeInsets.all(6), child: Text('ورود ساکن')),
        ),
      ),
      const SizedBox(height: 16),
      const Text('شماره‌ای که در برنامه ثبت شده است را وارد کنید',
          style: TextStyle(fontSize: 12, color: Colors.white38), textAlign: TextAlign.center),
    ]);
  }
}

// ═══════════════════ صفحه اصلی ═══════════════════

class HomeScreen extends StatefulWidget {
  final bool isAdmin;
  final String myMemberId;
  const HomeScreen({super.key, required this.isAdmin, this.myMemberId = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool get _isAdmin => widget.isAdmin;

  int _index = 0;
  int _payFilter = 0;
  bool _fontTried = false;
  pw.Font? _pdfFont;
  pw.Font? _pdfFontBold;

  List<Member> _members = [];
  List<Payment> _payments = [];
  List<Operation> _operations = [];
  String _bankName = 'پاسارگاد';
  String _cardNumber = '5022291058925981';
  late final TextEditingController _smsCtrl;

  static const _pageTitles = <int, String>{
    0: 'خانه',
    1: 'واحدها',
    2: 'پرداخت‌ها',
    3: 'عملیات ساختمان',
    4: 'گزارش‌ها',
    5: 'پیامک و یادآوری',
    6: 'تنظیمات',
  };
  static const _pageIcons = <int, List<IconData>>{
    0: [Icons.home_outlined, Icons.home_rounded],
    1: [Icons.people_outline_rounded, Icons.people_rounded],
    2: [Icons.payments_outlined, Icons.payments_rounded],
    3: [Icons.construction_outlined, Icons.construction_rounded],
    4: [Icons.description_outlined, Icons.description_rounded],
    5: [Icons.sms_outlined, Icons.sms_rounded],
    6: [Icons.settings_outlined, Icons.settings_rounded],
  };

  List<int> get _pages => _isAdmin ? [0, 1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 5];
  int get _pageKey => _pages[_index];

  Member? get _me {
    for (final m in _members) {
      if (m.id == widget.myMemberId) return m;
    }
    return null;
  }

  String get _adminPhone => Store.prefs.getString('admin_phone') ?? '';

  @override
  void initState() {
    super.initState();
    final p = Store.prefs;
    _members = ((jsonDecode(p.getString('members') ?? '[]') as List)
            .map((e) => Member.fromMap(Map<String, dynamic>.from(e))))
        .toList();
    _payments = ((jsonDecode(p.getString('payments') ?? '[]') as List)
            .map((e) => Payment.fromMap(Map<String, dynamic>.from(e))))
        .toList();
    _operations = ((jsonDecode(p.getString('operations') ?? '[]') as List)
            .map((e) => Operation.fromMap(Map<String, dynamic>.from(e))))
        .toList();
    _payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _operations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _bankName = p.getString('bank_name') ?? _bankName;
    _cardNumber = p.getString('card_number') ?? _cardNumber;
    _smsCtrl = TextEditingController(
        text: 'سلام 🌸\nلطفاً سهم ماهانه $appName را به کارت ${toFa(_cardNumber)} ($_bankName) واریز نمایید. با تشکر 🙏');
  }

  @override
  void dispose() {
    _smsCtrl.dispose();
    super.dispose();
  }

  int get _income => _payments.where((e) => e.isIncome).fold(0, (s, e) => s + e.amount);
  int get _expense => _payments.where((e) => !e.isIncome).fold(0, (s, e) => s + e.amount);
  int get _balance => _income - _expense;

  Future<void> _saveMembers() =>
      Store.prefs.setString('members', jsonEncode(_members.map((e) => e.toMap()).toList()));
  Future<void> _savePayments() =>
      Store.prefs.setString('payments', jsonEncode(_payments.map((e) => e.toMap()).toList()));
  Future<void> _saveOperations() =>
      Store.prefs.setString('operations', jsonEncode(_operations.map((e) => e.toMap()).toList()));

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

  void _logout() {
    Navigator.of(context).pushReplacement(_fadeRoute(const LoginScreen()));
  }

  // ---------- کارت پایه ----------
  Widget _card({required Widget child, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin,
    Gradient? gradient, Color? color, double radius = 18, VoidCallback? onTap, Color? borderColor}) {
    final deco = BoxDecoration(
      gradient: gradient,
      color: gradient == null ? (color ?? C.card) : null,
      borderRadius: BorderRadius.circular(radius),
      border: borderColor == null ? null : Border.all(color: borderColor, width: 1.2),
      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 6))],
    );
    final body = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: padding == null ? child : Padding(padding: padding, child: child),
      ),
    );
    return Container(margin: margin, decoration: deco, child: body);
  }

  Widget _empty(IconData icon, String title, String sub) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(28)),
            child: Icon(icon, size: 42, color: Colors.white24)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(sub, style: const TextStyle(fontSize: 13, color: Colors.white54)),
      ]),
    );
  }

  Widget _header() {
    return Row(children: [
      _logo(size: 48),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(appName,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: C.gold)),
          Text(fullJalali(), style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
      ),
    ]);
  }

  // ---------- ساختار و منو ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_pageKey] ?? appName),
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1B3A5C), Color(0xFF0E1E33)]))),
        actions: [
          IconButton(
              tooltip: 'خروج از حساب',
              icon: const Icon(Icons.logout_rounded, color: Colors.white70),
              onPressed: _logout),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF14263D), C.bg])),
        child: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.transparent,
            selectedIconTheme: const IconThemeData(color: C.gold, size: 26),
            unselectedIconTheme: const IconThemeData(color: Colors.white38, size: 24),
            selectedLabelTextStyle: const TextStyle(
                color: C.gold, fontSize: 10, fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white38, fontSize: 10),
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _logo(size: 44),
            ),
            destinations: [
              for (final p in _pages)
                NavigationRailDestination(
                  icon: Icon(_pageIcons[p]![0]),
                  selectedIcon: Icon(_pageIcons[p]![1]),
                  label: Text(_pageTitles[p]!),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(key: ValueKey('$_pageKey-$_isAdmin'), child: _page()),
            ),
          ),
        ]),
      ),
      floatingActionButton: !_isAdmin
          ? null
          : _pageKey == 1
              ? FloatingActionButton.extended(
                  onPressed: () => _memberDialog(),
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('واحد جدید'))
              : _pageKey == 2
                  ? FloatingActionButton.extended(
                      onPressed: _paymentDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('پرداخت جدید'))
                  : _pageKey == 3
                      ? FloatingActionButton.extended(
                          onPressed: _operationDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('ثبت عملیات'))
                      : null,
    );
  }

  Widget _page() {
    switch (_pageKey) {
      case 0:
        return _isAdmin ? _adminHome() : _residentHome();
      case 1:
        return _membersPage();
      case 2:
        return _paymentsPage();
      case 3:
        return _operationsPage();
      case 4:
        return _reportsPage();
      case 5:
        return _smsPage();
      default:
        return _settingsPage();
    }
  }

  // ---------- ۰) خانه مدیر ----------
  Widget _adminHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(),
        const SizedBox(height: 16),
        Text('👋 سلام مدیر عزیز',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.goldSoft)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _statCard('واحد', faNum(_members.length), Icons.people_alt_rounded,
                const [Color(0xFF3949AB), Color(0xFF5C6BC0)]),
            _statCard('درآمد (تومان)', faNum(_income), Icons.trending_up_rounded,
                const [Color(0xFF11998E), C.green]),
            _statCard('هزینه (تومان)', faNum(_expense), Icons.trending_down_rounded,
                const [Color(0xFFFF512F), C.red]),
            _statCard('موجودی (تومان)', faNum(_balance), Icons.account_balance_wallet_rounded,
                const [Color(0xFFF7971E), C.amber]),
          ],
        ),
        const SizedBox(height: 16),
        _card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          borderColor: C.gold.withOpacity(.35),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: C.gold.withOpacity(.18), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.credit_card_rounded, color: C.gold),
            ),
            title: const Text('کارت بانکی ساختمان', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$_bankName — ${toFa(_cardNumber)}',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, color: C.gold),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _cardNumber));
                _snack('شماره کارت کپی شد ✅');
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          ActionChip(
              avatar: const Icon(Icons.person_add_rounded, size: 18, color: C.goldSoft),
              label: const Text('افزودن واحد'),
              onPressed: () => _memberDialog()),
          ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18, color: C.green),
              label: const Text('ثبت پرداخت'),
              onPressed: _paymentDialog),
          ActionChip(
              avatar: const Icon(Icons.construction_rounded, size: 18, color: C.amber),
              label: const Text('ثبت عملیات'),
              onPressed: _operationDialog),
          ActionChip(
              avatar: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: C.red),
              label: const Text('خروجی PDF'),
              onPressed: _generatePdf),
        ]),
      ]),
    );
  }

  // ---------- ۰) خانه ساکن ----------
  Widget _residentHome() {
    final me = _me;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(),
        const SizedBox(height: 16),
        Text('👋 سلام ${me?.name ?? 'همسایه عزیز'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.goldSoft)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: C.blue.withOpacity(.15), borderRadius: BorderRadius.circular(20)),
          child: const Text('حالت مشاهده — دسترسی ویرایش ندارید',
              style: TextStyle(fontSize: 11, color: C.blue)),
        ),
        const SizedBox(height: 18),
        if (me != null) ...[
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _statCard('شارژ ماهیانه شما (تومان)', faNum(me.monthlyCharge),
                  Icons.calendar_month_rounded, const [Color(0xFF3949AB), Color(0xFF5C6BC0)]),
              _statCard('شارژ فصلی شما (تومان)', faNum(me.seasonalCharge),
                  Icons.calendar_view_week_rounded, const [Color(0xFFF7971E), C.amber]),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          borderColor: C.gold.withOpacity(.35),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: C.gold.withOpacity(.18), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.credit_card_rounded, color: C.gold),
            ),
            title: const Text('کارت بانکی ساختمان', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$_bankName — ${toFa(_cardNumber)}',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, color: C.gold),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _cardNumber));
                _snack('شماره کارت کپی شد ✅');
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _card(
          padding: const EdgeInsets.all(16),
          onTap: () => setState(() => _index = _pages.indexOf(5)),
          borderColor: C.blue.withOpacity(.4),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: C.blue.withOpacity(.18), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.support_agent_rounded, color: C.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('تماس با مدیر',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('ارتباط مستقیم با مدیریت ساختمان — از بخش پیامک و یادآوری',
                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ]),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.white24),
          ]),
        ),
        const SizedBox(height: 12),
        _card(
          padding: const EdgeInsets.all(16),
          onTap: () => setState(() => _index = _pages.indexOf(3)),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: C.amber.withOpacity(.18), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.construction_rounded, color: C.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('اعلام عملیات ساختمان',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${faNum(_operations.length)} مورد ثبت شده — برای مشاهده بزنید',
                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ]),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.white24),
          ]),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: colors.last.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration:
          BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const Spacer(),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ]),
    );
  }

  // ---------- ۱) واحدها ----------
  Widget _membersPage() {
    if (_members.isEmpty) {
      return _empty(Icons.people_outline_rounded, 'هنوز واحدی ثبت نشده',
          _isAdmin ? 'با دکمه پایین اولین واحد را اضافه کنید' : 'مدیر هنوز واحدی ثبت نکرده است');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = _members[i];
        final initial = m.name.trim().isNotEmpty ? m.name.trim().substring(0, 1) : '؟';
        return _card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            leading: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)]),
                  borderRadius: BorderRadius.circular(14)),
              child: Text(initial,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.call_rounded, size: 14, color: C.green),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text('مالک: ${toFa(m.ownerPhone)}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60))),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.phone_android_rounded, size: 14, color: C.blue),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text('مستأجر: ${m.tenantPhone.isEmpty ? '—' : toFa(m.tenantPhone)}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.calendar_month_rounded, size: 14, color: C.gold),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          'شارژ ماه: ${faNum(m.monthlyCharge)} • فصل: ${faNum(m.seasonalCharge)} تومان',
                          style: const TextStyle(fontSize: 12, color: C.goldSoft))),
                ]),
              ]),
            ),
            trailing: _isAdmin
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                    onSelected: (v) {
                      if (v == 'edit') {
                        _memberDialog(old: m);
                      } else {
                        _confirmDeleteMember(m);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded, size: 18, color: C.goldSoft),
                            SizedBox(width: 8),
                            Text('ویرایش'),
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_rounded, size: 18, color: C.red),
                            SizedBox(width: 8),
                            Text('حذف', style: TextStyle(color: C.red)),
                          ])),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  void _confirmDeleteMember(Member m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف واحد'),
        content: Text('«${m.name}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              setState(() => _members.removeWhere((e) => e.id == m.id));
              _saveMembers();
              Navigator.pop(ctx);
              _snack('واحد حذف شد');
            },
            child: const Text('حذف', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _memberDialog({Member? old}) async {
    final nameC = TextEditingController(text: old?.name ?? '');
    final ownerC = TextEditingController(text: old?.ownerPhone ?? '');
    final tenantC = TextEditingController(text: old?.tenantPhone ?? '');
    final monthlyC =
        TextEditingController(text: old == null ? '' : (old.monthlyCharge == 0 ? '' : '${old.monthlyCharge}'));
    final seasonalC =
        TextEditingController(text: old == null ? '' : (old.seasonalCharge == 0 ? '' : '${old.seasonalCharge}'));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.person_add_rounded, color: C.goldSoft),
          const SizedBox(width: 8),
          Text(old == null ? 'واحد جدید' : 'ویرایش واحد'),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameC,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'نام واحد (مثلاً: واحد ۲ — ali)',
                    prefixIcon: Icon(Icons.door_front_door_rounded, size: 20))),
            const SizedBox(height: 12),
            TextField(
                controller: ownerC,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'شماره مالک', prefixIcon: Icon(Icons.call_rounded, size: 20))),
            const SizedBox(height: 12),
            TextField(
                controller: tenantC,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'شماره مستأجر (اختیاری)',
                    prefixIcon: Icon(Icons.phone_android_rounded, size: 20))),
            const SizedBox(height: 12),
            TextField(
                controller: monthlyC,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'شارژ ماهیانه (تومان)',
                    prefixIcon: Icon(Icons.calendar_month_rounded, size: 20))),
            const SizedBox(height: 12),
            TextField(
                controller: seasonalC,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'شارژ فصلی (تومان)',
                    prefixIcon: Icon(Icons.calendar_view_week_rounded, size: 20))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty || ownerC.text.trim().isEmpty) {
                _snack('نام واحد و شماره مالک الزامی است');
                return;
              }
              final monthly = int.tryParse(monthlyC.text) ?? 0;
              final seasonal = int.tryParse(seasonalC.text) ?? 0;
              setState(() {
                if (old == null) {
                  _members.add(Member(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: nameC.text.trim(),
                      ownerPhone: ownerC.text.trim(),
                      tenantPhone: tenantC.text.trim(),
                      monthlyCharge: monthly,
                      seasonalCharge: seasonal));
                } else {
                  old.name = nameC.text.trim();
                  old.ownerPhone = ownerC.text.trim();
                  old.tenantPhone = tenantC.text.trim();
                  old.monthlyCharge = monthly;
                  old.seasonalCharge = seasonal;
                }
              });
              _saveMembers();
              Navigator.pop(ctx);
              _snack(old == null ? 'واحد اضافه شد ✅' : 'ویرایش شد ✅');
            },
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
  }

  // ---------- ۲) پرداخت‌ها ----------
  Widget _paymentLinkCard() {
    return _card(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: C.gold.withOpacity(.5),
      onTap: () => _snack('لینک پرداخت به‌زودی در آپدیت بعدی فعال می‌شود 🚧'),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: C.gold.withOpacity(.18), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.link_rounded, color: C.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('لینک پرداخت آنلاین',
                style: TextStyle(fontWeight: FontWeight.bold, color: C.goldSoft)),
            const SizedBox(height: 2),
            Text('لینک پرداخت $appName ... به‌زودی',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: C.amber.withOpacity(.15), borderRadius: BorderRadius.circular(20)),
          child: const Text('به‌زودی', style: TextStyle(fontSize: 11, color: C.amber)),
        ),
      ]),
    );
  }

  Widget _paymentsPage() {
    final filtered = _payFilter == 0
        ? _payments
        : _payments.where((e) => _payFilter == 1 ? e.isIncome : !e.isIncome).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(children: [
          Row(children: [
            Expanded(child: _miniStat('درآمد کل', _income, C.green)),
            const SizedBox(width: 10),
            Expanded(child: _miniStat('هزینه کل', _expense, C.red)),
          ]),
          const SizedBox(height: 10),
          _miniStat('موجودی صندوق', _balance, C.gold),
          _paymentLinkCard(),
          Row(children: [
            _filterChip('همه', 0),
            const SizedBox(width: 8),
            _filterChip('درآمد', 1),
            const SizedBox(width: 8),
            _filterChip('هزینه', 2),
          ]),
        ]),
      ),
      Expanded(
        child: filtered.isEmpty
            ? _empty(Icons.payments_outlined, 'پرداختی ثبت نشده',
            _isAdmin ? 'با دکمه پایین اولین پرداخت را ثبت کنید' : 'هنوز پرداختی ثبت نشده است')
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final p = filtered[i];
            final tile = _card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor:
                  (p.isIncome ? C.green : C.red).withOpacity(.15),
                  child: Icon(
                      p.isIncome
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: p.isIncome ? C.green : C.red),
                ),
                title: Text(p.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.member.isEmpty ? 'بدون واحد' : p.member} • ${p.date}',
                    style:
                    const TextStyle(fontSize: 12, color: Colors.white54)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${p.isIncome ? '+' : '-'} ${faNum(p.amount)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: p.isIncome ? C.green : C.red)),
                    const Text('تومان',
                        style: TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
            );
            if (!_isAdmin) return tile;
            return Dismissible(
              key: ValueKey(p.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: C.red.withOpacity(.85),
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              onDismissed: (_) {
                setState(() => _payments.remove(p));
                _savePayments();
                _snack('پرداخت حذف شد');
              },
              child: tile,
            );
          },
        ),
      ),
    ]);
  }

  Widget _miniStat(String label, int value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('${faNum(value)} تومان',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, int val) {
    final sel = _payFilter == val;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(fontSize: 12, color: sel ? C.bg : Colors.white60)),
      selected: sel,
      selectedColor: C.gold,
      backgroundColor: C.card2,
      side: BorderSide(color: sel ? C.gold : Colors.white12),
      onSelected: (_) => setState(() => _payFilter = val),
    );
  }

  Future<void> _paymentDialog() async {
    final titleC = TextEditingController();
    final amountC = TextEditingController();
    String member = '';
    bool income = true;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: C.card2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.payments_rounded, color: C.goldSoft),
            const SizedBox(width: 8),
            const Text('پرداخت جدید'),
          ]),
          content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                      controller: titleC,
                      textInputAction: TextInputAction.next,
                      decoration:
                      const InputDecoration(labelText: 'شرح (مثلاً: سهم ماهانه)')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: amountC,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'مبلغ (تومان)',
                          prefixIcon: Icon(Icons.payments_rounded, size: 18))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: member,
                    isExpanded: true,
                    dropdownColor: C.card2,
                    decoration:
                    const InputDecoration(labelText: 'واحد مرتبط (اختیاری)'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('بدون واحد')),
                      ..._members
                          .map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))),
                    ],
                    onChanged: (v) => setD(() => member = v ?? ''),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    ChoiceChip(
                        label: const Text('درآمد'),
                        selected: income,
                        selectedColor: C.green,
                        backgroundColor: C.card,
                        labelStyle: TextStyle(
                            color: income ? Colors.white : Colors.white60),
                        onSelected: (_) => setD(() => income = true)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                        label: const Text('هزینه'),
                        selected: !income,
                        selectedColor: C.red,
                        backgroundColor: C.card,
                        labelStyle: TextStyle(
                            color: !income ? Colors.white : Colors.white60),
                        onSelected: (_) => setD(() => income = false)),
                  ]),
                ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () {
                final amount = int.tryParse(amountC.text) ?? 0;
                if (titleC.text.trim().isEmpty || amount <= 0) {
                  _snack('شرح و مبلغ معتبر وارد کنید');
                  return;
                }
                setState(() {
                  _payments.insert(
                      0,
                      Payment(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          title: titleC.text.trim(),
                          amount: amount,
                          isIncome: income,
                          member: member,
                          date: todayJalali(),
                          createdAt: DateTime.now().millisecondsSinceEpoch));
                });
                _savePayments();
                Navigator.pop(ctx);
                _snack(income ? 'درآمد ثبت شد ✅' : 'هزینه ثبت شد ✅');
              },
              child: const Text('ثبت'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- ۳) عملیات ساختمان ----------
  Widget _operationsPage() {
    if (_operations.isEmpty) {
      return _empty(Icons.construction_outlined, 'عملیاتی ثبت نشده است',
          _isAdmin ? 'با دکمه پایین اولین عملیات را ثبت کنید' : 'مدیر هنوز عملیاتی ثبت نکرده است');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _operations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = _operations[i];
        return _card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: C.amber.withOpacity(.16), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.construction_rounded, color: C.amber),
            ),
            title: Text(o.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (o.detail.isNotEmpty)
                  Text(o.detail,
                      style: const TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.event_rounded, size: 13, color: C.goldSoft),
                  const SizedBox(width: 4),
                  Text(o.date, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                ]),
              ]),
            ),
            trailing: _isAdmin
                ? IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_rounded, color: C.red, size: 20),
                    onPressed: () => _confirmDeleteOperation(o))
                : null,
          ),
        );
      },
    );
  }

  void _confirmDeleteOperation(Operation o) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف عملیات'),
        content: Text('«${o.title}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              setState(() => _operations.removeWhere((e) => e.id == o.id));
              _saveOperations();
              Navigator.pop(ctx);
              _snack('عملیات حذف شد');
            },
            child: const Text('حذف', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _operationDialog() async {
    final titleC = TextEditingController();
    final detailC = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.construction_rounded, color: C.amber),
          const SizedBox(width: 8),
          const Text('ثبت عملیات ساختمان'),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: titleC,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'عنوان (مثلاً: شست‌وشوی نمای ساختمان)',
                    prefixIcon: Icon(Icons.title_rounded, size: 20))),
            const SizedBox(height: 12),
            TextField(
                controller: detailC,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'شرح عملیات (اختیاری)',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (titleC.text.trim().isEmpty) {
                _snack('عنوان عملیات را وارد کنید');
                return;
              }
              setState(() {
                _operations.insert(
                    0,
                    Operation(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        title: titleC.text.trim(),
                        detail: detailC.text.trim(),
                        date: todayJalali(),
                        createdAt: DateTime.now().millisecondsSinceEpoch));
              });
              _saveOperations();
              Navigator.pop(ctx);
              _snack('عملیات ثبت و به ساکنین اعلام شد ✅');
            },
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
  }

  // ---------- ۴) گزارش‌ها ----------
  Widget _reportsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF3949AB), Color(0xFF142A44)]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: C.gold.withOpacity(.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.analytics_rounded, color: C.gold),
              SizedBox(width: 8),
              Text('خلاصه وضعیت ساختمان',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 14),
            _sumRow('🏢 تعداد واحدها', '${faNum(_members.length)} واحد'),
            _sumRow('➕ درآمد کل', '${faNum(_income)} تومان'),
            _sumRow('➖ هزینه کل', '${faNum(_expense)} تومان'),
            _sumRow('💰 موجودی', '${faNum(_balance)} تومان'),
            _sumRow('🔧 عملیات ثبت‌شده', '${faNum(_operations.length)} مورد'),
          ]),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('خروجی PDF گزارش مالی'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _generatePdf,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.share_rounded),
          label: const Text('اشتراک متن گزارش'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => Share.share(_shareText()),
        ),
        const SizedBox(height: 24),
        const Text('ارسال سریع در پیام‌رسان‌ها',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _social('واتساپ', const Color(0xFF25D366), Icons.chat_rounded,
              'https://wa.me/?text=${Uri.encodeComponent(_shareText())}'),
          _social('تلگرام', const Color(0xFF29A9EB), Icons.send_rounded,
              'https://t.me/share/url?url=%20&text=${Uri.encodeComponent(_shareText())}'),
          _social('ایتا', const Color(0xFFFF7043), Icons.chat_bubble_rounded,
              'https://eitaa.com/share?text=${Uri.encodeComponent(_shareText())}'),
          _social('بله', const Color(0xFF26A69A), Icons.forum_rounded,
              'https://ble.ir/share?text=${Uri.encodeComponent(_shareText())}'),
        ]),
      ]),
    );
  }

  Widget _sumRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
    ]),
  );

  Widget _social(String label, Color color, IconData icon, String url) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(url),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: color.withOpacity(.18),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(.5))),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
    );
  }

  String _shareText() =>
      '📊 گزارش مالی $appName\n'
          '🗓 تاریخ: ${todayJalali()}\n'
          '🏢 واحدها: ${faNum(_members.length)} واحد\n'
          '➕ درآمد: ${faNum(_income)} تومان\n'
          '➖ هزینه: ${faNum(_expense)} تومان\n'
          '💰 موجودی: ${faNum(_balance)} تومان\n'
          '💳 کارت: $_bankName — ${toFa(_cardNumber)}';

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('برنامه موردنظر روی دستگاه نصب نیست');
    }
  }

  // ---------- ۵) پیامک و یادآوری ----------
  Widget _groupsCard() {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.groups_rounded, color: C.teal, size: 18),
          SizedBox(width: 8),
          Text('گروه‌های پیام‌رسانی', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        const Text('برای عضویت و ارسال پیام در گروه، بزنید:',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _groupBtn('گروه واتساپ', 'assets/images/ic_whatsapp.png',
              const Color(0xFF25D366), Icons.chat_rounded, waGroupUrl),
          _groupBtn('گروه بله', 'assets/images/ic_bale.png',
              const Color(0xFF26C6DA), Icons.verified_rounded, baleGroupUrl),
        ]),
      ]),
    );
  }

  Widget _groupBtn(String label, String asset, Color color, IconData fallbackIcon, String url) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(url),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: color.withOpacity(.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(.6), width: 1.5)),
            child: ClipOval(
              child: Image.asset(asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: color, size: 26)),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
    );
  }

  Widget _managerContactCard() {
    final phone = _adminPhone;
    return _card(
      padding: const EdgeInsets.all(14),
      borderColor: C.blue.withOpacity(.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.support_agent_rounded, color: C.blue, size: 18),
          SizedBox(width: 8),
          Text('تماس با مدیر', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        if (phone.isEmpty)
          const Text('مدیر هنوز شماره تماس خود را در برنامه ثبت نکرده است.',
              style: TextStyle(fontSize: 12, color: Colors.white54))
        else ...[
          Row(children: [
            const Icon(Icons.call_rounded, size: 16, color: C.green),
            const SizedBox(width: 6),
            Text(toFa(phone),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('تماس با مدیر'),
                onPressed: () => _open('tel:$phone'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.sms_rounded, size: 18),
                label: const Text('پیام به مدیر'),
                onPressed: () => _sendSms(phone,
                    body: 'سلام و احترام؛\nپیامی از سوی یکی از ساکنین $appName:\n'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
  Widget _smsPage() {
    if (!_isAdmin) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _managerContactCard(),
          const SizedBox(height: 12),
          _groupsCard(),
        ]),
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(children: [
          _card(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.notifications_active_rounded, color: C.amber, size: 18),
                SizedBox(width: 8),
                Text('یادآوری شارژ', style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('یادآوری ماهیانه'),
                    onPressed: () => _chargeReminderSheet(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
                    label: const Text('یادآوری فصلی'),
                    onPressed: () => _chargeReminderSheet(false),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          _card(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.campaign_rounded, color: C.teal, size: 18),
                SizedBox(width: 8),
                Text('پیام‌های آماده', style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.groups_rounded, size: 18),
                    label: const Text('جلسه ساختمان'),
                    onPressed: () => _templateDialog(
                      'پیام برگزاری جلسه ساختمان',
                      '📢 اطلاعیه جلسه $appName\n'
                          'با سلام و احترام؛\n'
                          'جلسه همسایگان روز ........ ساعت ........ در محل ........ برگزار می‌گردد.\n'
                          'حضور سبز شما موجی از همدلی است 🌸\n'
                          'با تشکر — مدیریت ساختمان',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                    label: const Text('پیام مدیر'),
                    onPressed: () => _templateDialog(
                      'پیام مدیر',
                      '📢 پیام مدیریت $appName\n'
                          'با سلام و احترام؛\n'
                          '................................................................\n'
                          'با تشکر — مدیریت ساختمان',
                    ),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          _groupsCard(),
          const SizedBox(height: 12),
          _card(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.sms_rounded, color: C.goldSoft, size: 18),
                SizedBox(width: 8),
                Text('متن پیام اطلاع‌رسانی', style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _smsCtrl, maxLines: 4, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.forward_to_inbox_rounded, size: 18),
                  label: const Text('ارسال گروهی (انتخاب برنامه)'),
                  onPressed: () => Share.share(_smsCtrl.text),
                ),
              ),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: _members.isEmpty
            ? _empty(Icons.contacts_outlined, 'واحدی وجود ندارد',
            'ابتدا از بخش واحدها، اعضا را اضافه کنید')
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: _members.length,
          itemBuilder: (_, i) {
            final m = _members[i];
            final phone = m.tenantPhone.isNotEmpty ? m.tenantPhone : m.ownerPhone;
            final role = m.tenantPhone.isNotEmpty ? 'مستأجر' : 'مالک';
            return _card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: const CircleAvatar(
                    backgroundColor: C.card2,
                    child: Icon(Icons.person_rounded, color: C.goldSoft)),
                title: Text(m.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('$role: ${toFa(phone)}',
                    style:
                    const TextStyle(fontSize: 12, color: Colors.white54)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: 'تماس',
                      icon: const Icon(Icons.call_rounded,
                          color: C.green, size: 20),
                      onPressed: () => _open('tel:$phone')),
                  IconButton(
                      tooltip: 'پیامک',
                      icon: const Icon(Icons.sms_rounded, color: C.blue, size: 20),
                      onPressed: () => _sendSms(phone)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _templateDialog(String title, String initial) async {
    final ctrl = TextEditingController(text: initial);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.edit_note_rounded, color: C.teal),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        ]),
        content: TextField(controller: ctrl, maxLines: 8, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Share.share(ctrl.text);
            },
            child: const Text('ارسال'),
          ),
        ],
      ),
    );
  }

  String _chargeMsg(Member m, bool monthly) {
    final amt = monthly ? m.monthlyCharge : m.seasonalCharge;
    final period = monthly ? 'ماهیانه' : 'فصلی';
    return 'سلام 🌸\nشارژ $period واحد «${m.name}» مبلغ ${faNum(amt)} تومان می‌باشد.\n'
        'لطفاً به کارت ${toFa(_cardNumber)} ($_bankName) واریز گردد.\nبا تشکر — مدیریت $appName 🙏';
  }

  void _chargeReminderSheet(bool monthly) {
    final list = _members.where((m) => (monthly ? m.monthlyCharge : m.seasonalCharge) > 0).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(monthly ? Icons.calendar_month_rounded : Icons.calendar_view_week_rounded,
                  color: C.gold),
              const SizedBox(width: 8),
              Text(monthly ? 'یادآوری شارژ ماهیانه' : 'یادآوری شارژ فصلی',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('هیچ واحدی شارژ تعریف‌شده ندارد.\nاز بخش واحدها > ویرایش، مبلغ شارژ را وارد کنید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white54)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final phone = m.tenantPhone.isNotEmpty ? m.tenantPhone : m.ownerPhone;
                    return ListTile(
                      leading: const Icon(Icons.person_rounded, color: C.goldSoft),
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${faNum(monthly ? m.monthlyCharge : m.seasonalCharge)} تومان — ${toFa(phone)}',
                          style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: 'تماس',
                            icon: const Icon(Icons.call_rounded, color: C.green, size: 20),
                            onPressed: () => _open('tel:$phone')),
                        IconButton(
                            tooltip: 'ارسال پیامک یادآوری',
                            icon: const Icon(Icons.sms_rounded, color: C.blue, size: 20),
                            onPressed: () => _sendSms(phone, body: _chargeMsg(m, monthly))),
                      ]),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _sendSms(String phone, {String? body}) async {
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': body ?? _smsCtrl.text});
    try {
      await launchUrl(uri);
    } catch (_) {
      _snack('ارسال پیامک ممکن نشد');
    }
  }

  // ---------- ۶) تنظیمات ----------
  Widget _settingsPage() {
    final masked = _cardNumber.length >= 4
        ? '**** ${toFa(_cardNumber.substring(_cardNumber.length - 4))}'
        : toFa(_cardNumber);
    final adminPhone = _adminPhone;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _section('حساب مدیر'),
      _tile(Icons.key_rounded, 'تغییر رمز عبور', 'رمز ورود مدیر را عوض کنید',
          onTap: _changePassDialog),
      const SizedBox(height: 10),
      _tile(Icons.support_agent_rounded, 'شماره تماس مدیر',
          adminPhone.isEmpty ? 'ثبت نشده — برای نمایش به ساکنین ثبت کنید' : toFa(adminPhone),
          onTap: _adminPhoneDialog),
      const SizedBox(height: 10),
      _section('اطلاعات بانکی'),
      _tile(Icons.credit_card_rounded, 'کارت بانکی ساختمان', '$_bankName — $masked',
          onTap: _bankDialog),
      const SizedBox(height: 10),
      _section('داده‌ها'),
      _tile(Icons.delete_sweep_rounded, 'پاک کردن همه داده‌ها', 'حذف واحدها، پرداخت‌ها و عملیات',
          color: C.red, onTap: _confirmReset),
      const SizedBox(height: 10),
      _section('حساب کاربری'),
      _tile(Icons.logout_rounded, 'خروج از حساب', 'بازگشت به صفحه ورود',
          color: C.blue, onTap: _logout),
      const SizedBox(height: 14),
      _aboutCard(),
      const SizedBox(height: 10),
      Text('$appName — نسخه ۳٫۰٫۰',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.white38)),
    ]);
  }

  Widget _aboutCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [C.gold.withOpacity(.14), C.card2]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.gold.withOpacity(.5)),
      ),
      child: Column(children: [
        _logo(size: 56),
        const SizedBox(height: 10),
        const Text('این جهان کوه است و فعل ما ندا',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.goldSoft, height: 1.9)),
        const Text('سوی ما آید نداها را صدا',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.goldSoft, height: 1.9)),
        const SizedBox(height: 6),
        const Text('— مولانا —',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.gold)),
      ]),
    );
  }

  Widget _section(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(t,
          style: const TextStyle(
              fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold)));

  Widget _tile(IconData icon, String title, String sub,
      {Color? color, VoidCallback? onTap}) {
    return _card(
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: (color ?? C.gold).withOpacity(.16),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color ?? C.goldSoft),
        ),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.white)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        trailing: const Icon(Icons.chevron_left_rounded, color: Colors.white24),
      ),
    );
  }

  Future<void> _adminPhoneDialog() async {
    final phoneC = TextEditingController(text: _adminPhone);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.support_agent_rounded, color: C.blue),
          const SizedBox(width: 8),
          const Text('شماره تماس مدیر'),
        ]),
        content: TextField(
            controller: phoneC,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'مثلاً: 09121234567', counterText: '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (!RegExp(r'^\d{11}$').hasMatch(phoneC.text)) {
                _snack('شماره موبایل باید ۱۱ رقم باشد');
                return;
              }
              Store.prefs.setString('admin_phone', phoneC.text);
              Navigator.pop(ctx);
              setState(() {});
              _snack('شماره مدیر ذخیره شد ✅');
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassDialog() async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final confirmC = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.key_rounded, color: C.goldSoft),
          const SizedBox(width: 8),
          const Text('تغییر رمز عبور'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: oldC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'رمز فعلی')),
          const SizedBox(height: 12),
          TextField(
              controller: newC,
              obscureText: true,
              decoration:
              const InputDecoration(labelText: 'رمز جدید (حداقل ۴ رقم)')),
          const SizedBox(height: 12),
          TextField(
              controller: confirmC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'تکرار رمز جدید')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              final current = Store.prefs.getString('admin_pass') ?? '1234';
              if (oldC.text != current) {
                _snack('رمز فعلی نادرست است');
                return;
              }
              if (newC.text.length < 4) {
                _snack('رمز جدید حداقل ۴ کاراکتر باشد');
                return;
              }
              if (newC.text != confirmC.text) {
                _snack('تکرار رمز مطابقت ندارد');
                return;
              }
              Store.prefs.setString('admin_pass', newC.text);
              Navigator.pop(ctx);
              _snack('رمز عبور تغییر کرد ✅');
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  Future<void> _bankDialog() async {
    final bankC = TextEditingController(text: _bankName);
    final cardC = TextEditingController(text: _cardNumber);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.credit_card_rounded, color: C.goldSoft),
          const SizedBox(width: 8),
          const Text('اطلاعات کارت بانکی'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: bankC,
              decoration: const InputDecoration(labelText: 'نام بانک')),
          const SizedBox(height: 12),
          TextField(
              controller: cardC,
              keyboardType: TextInputType.number,
              maxLength: 16,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'شماره کارت (۱۶ رقم)', counterText: '')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (!RegExp(r'^\d{16}$').hasMatch(cardC.text)) {
                _snack('شماره کارت باید ۱۶ رقم باشد');
                return;
              }
              setState(() {
                _bankName = bankC.text.trim();
                _cardNumber = cardC.text;
              });
              Store.prefs.setString('bank_name', _bankName);
              Store.prefs.setString('card_number', _cardNumber);
              Navigator.pop(ctx);
              _snack('اطلاعات کارت ذخیره شد ✅');
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('پاک کردن داده‌ها', style: TextStyle(color: C.red)),
        content:
        const Text('همه واحدها، پرداخت‌ها و عملیات برای همیشه حذف می‌شوند. مطمئنید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              setState(() {
                _members.clear();
                _payments.clear();
                _operations.clear();
              });
              _saveMembers();
              _savePayments();
              _saveOperations();
              Navigator.pop(ctx);
              _snack('همه داده‌ها پاک شد');
            },
            child: const Text('حذف', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
  }

  // ---------- تولید PDF با فونت فارسی ----------
  Future<void> _ensurePdfFonts() async {
    if (_fontTried) return;
    _fontTried = true;
    try {
      _pdfFont = pw.Font.ttf(await rootBundle.load('assets/fonts/BNazanin.ttf'));
    } catch (_) {
      try {
        _pdfFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
      } catch (_) {}
    }
    try {
      _pdfFontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    } catch (_) {
      _pdfFontBold = _pdfFont;
    }
  }

  pw.TextStyle _ts({double size = 11, bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
          font: bold ? (_pdfFontBold ?? _pdfFont) : _pdfFont,
          fontSize: size,
          color: color ?? PdfColors.black);

  pw.Widget _pdfSummary() {
    pw.Widget box(String label, String value, PdfColor color) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        margin: const pw.EdgeInsets.symmetric(horizontal: 3),
        decoration:
        pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(children: [
          pw.Text(label, style: _ts(size: 9, color: PdfColors.white)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: _ts(size: 12, bold: true, color: PdfColors.white)),
        ]),
      ),
    );
    return pw.Row(children: [
      box('واحدها', '${faNum(_members.length)}', PdfColor.fromInt(0xFF3949AB)),
      box('درآمد', faNum(_income), PdfColor.fromInt(0xFF11998E)),
      box('هزینه', faNum(_expense), PdfColor.fromInt(0xFFE05263)),
      box('موجودی', faNum(_balance), PdfColor.fromInt(0xFFF7971E)),
    ]);
  }

  Future<void> _generatePdf() async {
    await _ensurePdfFonts();
    if (_pdfFont == null && mounted) {
      _snack('⚠️ فونت فارسی یافت نشد؛ متن فارسی در PDF درست دیده نمی‌شود');
    }
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF142A44),
                    borderRadius: pw.BorderRadius.circular(12)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$appName — گزارش مالی',
                        style: _ts(size: 18, bold: true, color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text('تاریخ گزارش: ${todayJalali()}',
                        style: _ts(size: 11, color: PdfColors.white)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              _pdfSummary(),
              pw.SizedBox(height: 16),
              pw.Text('فهرست پرداخت‌ها', style: _ts(size: 14, bold: true)),
              pw.SizedBox(height: 8),
              _payments.isEmpty
                  ? pw.Text('پرداختی ثبت نشده است.',
                  style: _ts(size: 10, color: PdfColors.grey))
                  : pw.TableHelper.fromTextArray(
                headers: ['شرح', 'واحد', 'نوع', 'مبلغ (تومان)', 'تاریخ'],
                data: _payments
                    .map((p) => [
                  p.title,
                  p.member.isEmpty ? '—' : p.member,
                  p.isIncome ? 'درآمد' : 'هزینه',
                  faNum(p.amount),
                  p.date,
                ])
                    .toList(),
                headerStyle: _ts(size: 10, bold: true, color: PdfColors.white),
                headerDecoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFF3949AB)),
                cellStyle: _ts(size: 9),
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
                oddRowDecoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F0FB)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('واحدها و شارژها', style: _ts(size: 14, bold: true)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['واحد', 'شارژ ماهیانه', 'شارژ فصلی', 'شماره مالک', 'شماره مستأجر'],
                data: _members
                    .map((m) => [
                  m.name,
                  faNum(m.monthlyCharge),
                  faNum(m.seasonalCharge),
                  toFa(m.ownerPhone),
                  m.tenantPhone.isEmpty ? '—' : toFa(m.tenantPhone),
                ])
                    .toList(),
                headerStyle: _ts(size: 10, bold: true, color: PdfColors.white),
                headerDecoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFF3949AB)),
                cellStyle: _ts(size: 9),
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
              ),
              pw.SizedBox(height: 20),
              pw.Text('اعلام عملیات انجام‌شده', style: _ts(size: 14, bold: true)),
              pw.SizedBox(height: 8),
              _operations.isEmpty
                  ? pw.Text('عملیاتی ثبت نشده است.',
                  style: _ts(size: 10, color: PdfColors.grey))
                  : pw.TableHelper.fromTextArray(
                headers: ['عنوان', 'شرح', 'تاریخ'],
                data: _operations
                    .map((o) => [
                  o.title,
                  o.detail.isEmpty ? '—' : o.detail,
                  o.date,
                ])
                    .toList(),
                headerStyle: _ts(size: 10, bold: true, color: PdfColors.white),
                headerDecoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFF3949AB)),
                cellStyle: _ts(size: 9),
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColors.grey300),
              pw.Text('شماره کارت $_bankName: ${toFa(_cardNumber)}',
                  style: _ts(size: 9, color: PdfColors.grey),
                  textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      ],
    ));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/shahriar_report.pdf');
    await file.writeAsBytes(await pdf.save());
    if (!mounted) return;
    await Share.shareXFiles([XFile(file.path)], text: 'گزارش مالی $appName 📊');
  }
}