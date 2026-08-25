import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/widgets/premium_effects.dart';
import 'package:tripproject/services/expenses_service.dart';
import 'package:tripproject/services/app_data_provider.dart';

class ExpensesSheet extends StatefulWidget {
  const ExpensesSheet({super.key, required this.isAr});

  final bool isAr;

  @override
  State<ExpensesSheet> createState() => _ExpensesSheetState();
}

class _ExpensesSheetState extends State<ExpensesSheet> {
  bool _showAddForm = false;
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _currency = kSupportedCurrencies.first;
  String _category = 'other';

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    ExpensesService.instance.addExpense(
      title: _titleController.text,
      amount: amount,
      currency: _currency,
      category: _category,
    );
    _titleController.clear();
    _amountController.clear();
    setState(() => _showAddForm = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gilded = AppDataProvider.instance.premiumThemeActive;

    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: gilded
              ? AppColors.pGold.withValues(alpha: isDark ? 0.45 : 0.6)
              : isDark
                  ? AppColors.glassBorder
                  : Colors.black.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: gilded
                ? AppColors.pGoldDeep.withValues(alpha: isDark ? 0.30 : 0.18)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: ListenableBuilder(
        listenable: ExpensesService.instance,
        builder: (context, _) {
          final items = ExpensesService.instance.items;
          final totals = ExpensesService.instance.totalsByCurrency;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gilded
                            ? [AppColors.pGoldSoft, AppColors.pGoldDeep]
                            : [
                                AppColors.expensesCard.withValues(alpha: 0.85),
                                AppColors.expensesCard,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (gilded ? AppColors.pGoldDeep : AppColors.expensesCard)
                              .withValues(alpha: isDark ? 0.35 : 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: gilded ? Colors.black.withValues(alpha: 0.75) : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: gilded
                        ? GoldText(
                            isAr ? 'المصاريف' : 'Expenses',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                          )
                        : Text(
                            isAr ? 'المصاريف' : 'Expenses',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                  ),
                  IconButton.filled(
                    onPressed: () => setState(() => _showAddForm = !_showAddForm),
                    style: IconButton.styleFrom(
                      backgroundColor: _showAddForm
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)
                          : gilded
                              ? AppColors.pGoldDeep
                              : AppColors.expensesCard,
                      shadowColor: (gilded ? AppColors.pGoldDeep : AppColors.expensesCard)
                          .withValues(alpha: 0.4),
                      elevation: _showAddForm ? 0 : 4,
                    ),
                    icon: AnimatedRotation(
                      turns: _showAddForm ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _showAddForm ? Icons.close_rounded : Icons.add_rounded,
                          key: ValueKey(_showAddForm),
                          color: _showAddForm
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Premium analytics section
              if (AppDataProvider.instance.isSubscribed && items.isNotEmpty) ...[
                _buildPremiumAnalytics(context, isAr),
                const SizedBox(height: 14),
              ],

              // Totals row
              if (totals.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: totals.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.expensesCard.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.expensesCard.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${AppDataProvider.instance.nfd(e.value, decimals: 2)} ${e.key}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.expensesCard,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (totals.isNotEmpty) const SizedBox(height: 14),

              // Add form — collapses/expands smoothly
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_showAddForm
                    ? const SizedBox(width: double.infinity)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - t)),
                            child: child,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _titleController,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: isAr ? 'الوصف (مثال: بنزين)' : 'Description (e.g. Fuel)',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: isAr ? 'المبلغ' : 'Amount',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _currency,
                                    style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                                      ),
                                    ),
                                    items: kSupportedCurrencies
                                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                        .toList(),
                                    onChanged: (v) => setState(() => _currency = v ?? _currency),
                                  ),
                                ),
                              ],
                            ),
                const SizedBox(height: 10),
                // Category picker
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kExpenseCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = kExpenseCategories[index];
                      final selected = _category == category.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(19),
                        onTap: () => setState(() => _category = category.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.expensesCard.withValues(alpha: 0.18)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: selected
                                  ? AppColors.expensesCard.withValues(alpha: 0.6)
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                category.icon,
                                size: 15,
                                color: selected
                                    ? AppColors.expensesCard
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                category.label(isAr: isAr),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  color: selected
                                      ? AppColors.expensesCard
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      gilded ? AppColors.pGoldDeep : AppColors.expensesCard,
                                  foregroundColor: Colors.white,
                                  elevation: gilded ? 6 : 2,
                                  shadowColor: (gilded ? AppColors.pGoldDeep : AppColors.expensesCard)
                                      .withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                                  ),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(isAr ? 'إضافة المصروف' : 'Add Expense'),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

              // List
              Flexible(
                child: items.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      isAr ? 'لا توجد مصاريف بعد' : 'No expenses yet',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => ExpensesService.instance.removeExpense(item.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.expensesCard.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            expenseCategoryById(item.category).icon,
                            size: 17,
                            color: AppColors.expensesCard,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${AppDataProvider.instance.nfi(item.date.day)}/${AppDataProvider.instance.nfi(item.date.month)}/${AppDataProvider.instance.nfi(item.date.year)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${AppDataProvider.instance.nfd(item.amount, decimals: 2)} ${item.currency}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.expensesCard,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => ExpensesService.instance.removeExpense(item.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumAnalytics(BuildContext context, bool isAr) {
    final service = ExpensesService.instance;
    final provider = AppDataProvider.instance;
    final gilded = provider.premiumThemeActive;
    final accent = gilded ? AppColors.pGold : AppColors.expensesCard;
    final radius = BorderRadius.circular(AppTheme.borderRadiusSmall);

    final header = Row(
      children: [
        Icon(Icons.workspace_premium_rounded, color: accent, size: 16),
        const SizedBox(width: 8),
        if (gilded)
          GoldText(
            isAr ? 'تحليلات متقدمة' : 'Premium Analytics',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Text(
            isAr ? 'تحليلات متقدمة' : 'Premium Analytics',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
      ],
    );

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!gilded) ...[header, const SizedBox(height: 12)],
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _AnalyticsTile(
              icon: Icons.account_balance_wallet_rounded,
              label: isAr ? 'إجمالي المصروفات' : 'Total Spent',
              value: provider.nfd(service.totalExpenses, decimals: 2),
              color: accent,
            ),
            _AnalyticsTile(
              icon: Icons.calculate_rounded,
              label: isAr ? 'متوسط المصروف' : 'Avg Expense',
              value: provider.nfd(service.averageExpense, decimals: 2),
              color: accent,
            ),
            _AnalyticsTile(
              icon: Icons.calendar_today_rounded,
              label: isAr ? 'آخر 30 يوم' : 'Last 30 Days',
              value: provider.nfd(service.recentTotal, decimals: 2),
              color: accent,
            ),
            if (service.highestExpense != null)
              _AnalyticsTile(
                icon: Icons.arrow_upward_rounded,
                label: isAr ? 'أعلى مصروف' : 'Highest',
                value: provider.nfd(service.highestExpense!.amount, decimals: 2),
                color: gilded ? AppColors.pGoldSoft : AppColors.success,
              ),
            if (service.lowestExpense != null)
              _AnalyticsTile(
                icon: Icons.arrow_downward_rounded,
                label: isAr ? 'أقل مصروف' : 'Lowest',
                value: provider.nfd(service.lowestExpense!.amount, decimals: 2),
                color: gilded ? AppColors.pGoldDeep : AppColors.warning,
              ),
          ],
        ),
        if (service.totalsByCategory.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildSectionLabel(context, isAr ? 'حسب الفئة' : 'By Category', accent),
          const SizedBox(height: 8),
          ...service.totalsByCategory.entries.map(
            (e) => _CategoryShareBar(
              category: expenseCategoryById(e.key),
              amount: e.value,
              shareOfTotal: service.totalExpenses > 0
                  ? e.value / service.totalExpenses
                  : 0.0,
              accent: accent,
              isAr: isAr,
            ),
          ),
        ],
        if (_recentMonthlyTotals(service).length >= 2) ...[
          const SizedBox(height: 14),
          _buildSectionLabel(context, isAr ? 'الاتجاه الشهري' : 'Monthly Trend', accent),
          const SizedBox(height: 8),
          _MiniMonthlyChart(
            totals: _recentMonthlyTotals(service),
            accent: accent,
            isAr: isAr,
          ),
        ],
      ],
    );

    if (gilded) {
      // Exclusive "Obsidian & Gold" presentation for subscribers.
      return GildedCard(
        borderRadius: AppTheme.borderRadiusSmall,
        padding: const EdgeInsets.all(14),
        sheen: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, const SizedBox(height: 12), content],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.expensesCard.withValues(alpha: 0.1),
            AppColors.expensesCard.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: radius,
        border: Border.all(color: AppColors.expensesCard.withValues(alpha: 0.25)),
      ),
      child: content,
    );
  }

  /// Last up-to-5 months of spending, oldest first, keyed `M/YY`.
  static Map<String, double> _recentMonthlyTotals(ExpensesService service) {
    final now = DateTime.now();
    final keys = <String>[];
    for (var i = 4; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      keys.add('${m.month}/${(m.year % 100).toString().padLeft(2, '0')}');
    }
    final monthly = service.monthlyTotals;
    final result = <String, double>{};
    for (final key in keys) {
      // monthlyTotals uses zero-padded `YYYY-MM`; map it to our M/YY key.
      final parts = key.split('/');
      final month = int.parse(parts[0]);
      final year = 2000 + int.parse(parts[1]);
      final paddedKey =
          '$year-${month.toString().padLeft(2, '0')}';
      final total = monthly[paddedKey];
      if (total != null && total > 0) result[key] = total;
    }
    return result;
  }

  Widget _buildSectionLabel(BuildContext context, String text, Color accent) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
      ).copyWith(color: accent.withValues(alpha: 0.9)),
    );
  }
}

/// One row of the per-category breakdown: icon + name on the left,
/// proportional gold bar underneath spanning its share of total spend,
/// amount + percentage on the right.
class _CategoryShareBar extends StatelessWidget {
  const _CategoryShareBar({
    required this.category,
    required this.amount,
    required this.shareOfTotal,
    required this.accent,
    required this.isAr,
  });

  final ExpenseCategory category;
  final double amount;
  final double shareOfTotal;
  final Color accent;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final provider = AppDataProvider.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, size: 13, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  category.label(isAr: isAr),
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${provider.nfd(amount, decimals: 2)} • ${(shareOfTotal * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
                ),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: shareOfTotal < 0.02
                      ? 0.02
                      : (shareOfTotal > 1.0 ? 1.0 : shareOfTotal),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withValues(alpha: 0.65), accent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact vertical bar chart of the last few months of spending.
class _MiniMonthlyChart extends StatelessWidget {
  const _MiniMonthlyChart({
    required this.totals,
    required this.accent,
    required this.isAr,
  });

  final Map<String, double> totals; // oldest → newest
  final Color accent;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList();
    final maxTotal = entries.map((e) => e.value).reduce(math.max);
    return SizedBox(
      height: 74,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in entries) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppDataProvider.instance.nfd(e.value, decimals: 0),
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FractionallySizedBox(
                    widthFactor: 0.55,
                    child: Container(
                      height: math.max(34 * (e.value / maxTotal), 5.0).toDouble(),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [accent.withValues(alpha: 0.45), accent],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.key,
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (e != entries.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  const _AnalyticsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
