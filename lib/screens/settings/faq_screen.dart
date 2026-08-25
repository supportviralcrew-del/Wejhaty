import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/utils/responsive.dart';
import 'package:tripproject/services/app_data_provider.dart';

class _FaqItem {
  const _FaqItem({required this.questionEn, required this.questionAr, required this.answerEn, required this.answerAr});
  final String questionEn;
  final String questionAr;
  final String answerEn;
  final String answerAr;
}

const _faqItems = [
  _FaqItem(
    questionEn: 'Why does the app show Saudi Arabia when I open it?',
    questionAr: 'لماذا يعرض التطبيق السعودية عند فتحه؟',
    answerEn: 'If location access isn\'t available yet, the app shows Saudi '
        'Arabia and a route to Makkah as sensible defaults so it\'s still '
        'useful right away. Enable location access, or search for a city '
        'manually in Settings → App Location, to switch to your own trip.',
    answerAr: 'إذا لم يكن الوصول إلى الموقع متاحاً بعد، يعرض التطبيق السعودية '
        'ومساراً إلى مكة المكرمة كإعداد افتراضي مفيد فوراً. فعّل صلاحية الموقع، '
        'أو ابحث عن مدينة يدوياً من الإعدادات ← موقع التطبيق، للتبديل إلى رحلتك.',
  ),
  _FaqItem(
    questionEn: 'How accurate are the emergency numbers?',
    questionAr: 'ما مدى دقة أرقام الطوارئ؟',
    answerEn: 'Core numbers (police, ambulance, fire) for the Gulf and '
        'nearby countries are hand-verified against official government '
        'sources. For other countries, the app fetches live data from a '
        'public emergency-number directory. If neither is available, it '
        'shows a generic 112/911 guess and clearly labels it as such.',
    answerAr: 'الأرقام الأساسية (الشرطة، الإسعاف، الدفاع المدني) لدول الخليج '
        'والدول المجاورة تم التحقق منها يدوياً من مصادر حكومية رسمية. بالنسبة '
        'للدول الأخرى، يجلب التطبيق البيانات مباشرة من دليل عام لأرقام '
        'الطوارئ. إن لم يتوفر أي منهما، يعرض تخميناً عاماً (112/911) مع توضيح '
        'ذلك بشكل واضح.',
  ),
  _FaqItem(
    questionEn: 'Are the trip statistics exact?',
    questionAr: 'هل إحصائيات الرحلة دقيقة تماماً؟',
    answerEn: 'Distance, fuel, time and score figures are well-informed '
        'estimates, not a routed calculation from a live directions '
        'service. Weather, elevation and locality figures are real data '
        'pulled live for your start and end points. Live traffic and toll '
        'costs aren\'t available yet and are labeled as such rather than '
        'guessed.',
    answerAr: 'أرقام المسافة والوقود والوقت والتقييمات هي تقديرات مدروسة، '
        'وليست حساباً دقيقاً لمسار فعلي من خدمة ملاحة مباشرة. أما بيانات '
        'الطقس والارتفاع والموقع فهي بيانات حقيقية يتم جلبها مباشرة لنقطتي '
        'البداية والنهاية. حركة المرور المباشرة ورسوم الطرق غير متوفرة حالياً '
        'ويُشار إلى ذلك بوضوح بدلاً من تخمينها.',
  ),
  _FaqItem(
    questionEn: 'Does the app work without an internet connection?',
    questionAr: 'هل يعمل التطبيق بدون اتصال بالإنترنت؟',
    answerEn: 'Previously loaded weather, prayer times and your saved '
        'checklist/expenses/photos stay available offline. Live lookups — '
        'trip statistics, emergency numbers for uncovered countries, and '
        'searching for a new city — need a connection.',
    answerAr: 'تبقى بيانات الطقس وأوقات الصلاة المحمّلة سابقاً، بالإضافة إلى '
        'قائمة التحقق والمصاريف والصور المحفوظة، متاحة دون اتصال. أما عمليات '
        'الجلب المباشر — كإحصائيات الرحلة، وأرقام الطوارئ لدول غير مشمولة، '
        'والبحث عن مدينة جديدة — فتحتاج إلى اتصال بالإنترنت.',
  ),
  _FaqItem(
    questionEn: 'Can I switch between Arabic and English?',
    questionAr: 'هل يمكنني التبديل بين العربية والإنجليزية؟',
    answerEn: 'Yes — go to Settings → App Language. The whole interface, '
        'including layout direction and number formatting, switches '
        'immediately.',
    answerAr: 'نعم — من الإعدادات ← لغة التطبيق. تتغير الواجهة بالكامل فوراً، '
        'بما في ذلك اتجاه التخطيط وتنسيق الأرقام.',
  ),
  _FaqItem(
    questionEn: 'How do I report a problem or suggest a feature?',
    questionAr: 'كيف يمكنني الإبلاغ عن مشكلة أو اقتراح ميزة؟',
    answerEn: 'Use Settings → Email us — we read every message.',
    answerAr: 'استخدم الإعدادات ← راسلنا بالإيميل — نقرأ كل رسالة تصلنا.',
  ),
];

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = AppDataProvider.instance.language == 'ar';
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final padding = Responsive.horizontalPadding(context);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            isAr ? 'الأسئلة الشائعة' : 'FAQ',
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        body: ResponsiveCenter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 60),
                itemCount: _faqItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _faqItems[index];
                  return _FaqTile(
                    question: isAr ? item.questionAr : item.questionEn,
                    answer: isAr ? item.answerAr : item.answerEn,
                    isAr: isAr,
                    onSurface: onSurface,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer, required this.isAr, required this.onSurface});

  final String question;
  final String answer;
  final bool isAr;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          iconColor: AppColors.primary,
          collapsedIconColor: onSurface.withValues(alpha: 0.4),
          title: Text(
            question,
            textAlign: isAr ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                textAlign: isAr ? TextAlign.right : TextAlign.left,
                style: GoogleFonts.inter(fontSize: 13, height: 1.6, color: onSurface.withValues(alpha: 0.65)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}