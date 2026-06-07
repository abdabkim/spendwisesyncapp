// COMPLETE SHOPPING CALCULATOR - PROPERLY FIXED

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class ShoppingCalculator extends StatefulWidget {
  const ShoppingCalculator({Key? key}) : super(key: key);

  @override
  State<ShoppingCalculator> createState() => _ShoppingCalculatorState();
}

class _ShoppingCalculatorState extends State<ShoppingCalculator> {
  // App Colors - DARK MODE
  static const Color backgroundDark = Color(0xFF0f1419);
  static const Color cardDark = Color(0xFF1a1d24);
  static const Color cardSurface = Color(0xFF252931);
  static const Color borderDark = Color(0xFF2d3542);
  static const Color textGreyDark = Color(0xFF94a3b8);
  static const Color textLightDark = Color(0xFFe2e8f0);

  // App Colors - LIGHT MODE
  static const Color backgroundLight = Color(0xFFf6f7f8);
  static const Color cardLight = Color(0xFFffffff);
  static const Color cardSurfaceLight = Color(0xFFf1f5f9);
  static const Color borderLight = Color(0xFFe2e8f0);
  static const Color textGreyLight = Color(0xFF64748b);
  static const Color textLightLight = Color(0xFF0f172a);

  // Shared colors
  static const Color primary = Color(0xFF00d4ff);
  static const Color redError = Color(0xFFef4444);
  static const Color greenSuccess = Color(0xFF10b981);

  final TextEditingController _displayController = TextEditingController(
    text: '0',
  );
  final FocusNode _displayFocusNode = FocusNode();

  double _baseAmount = 0;
  double _gctRate = 15;
  double _serviceRate = 10;
  double _discountRate = 2;

  bool _priceIncludesTax = false;
  bool _discountFirst = true;
  bool _applyServiceCharge = false;
  bool _applyDiscount = false;

  String _selectedCountry = 'Jamaica';
  String _currencySymbol = '\$';

  List<Map<String, dynamic>> _cartItems = [];

  final Map<String, Map<String, dynamic>> _countryPresets = {
    'Jamaica': {'tax': 15.0, 'currency': '\$', 'name': 'GCT'},
    'USA': {'tax': 8.0, 'currency': '\$', 'name': 'Sales Tax'},
    'UK': {'tax': 20.0, 'currency': '£', 'name': 'VAT'},
    'Canada': {'tax': 13.0, 'currency': 'CAD \$', 'name': 'HST'},
    'EU': {'tax': 19.0, 'currency': '€', 'name': 'VAT'},
  };

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _displayController.addListener(_onDisplayChanged);
    _updateCalculation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSystemUI();
  }

  void _updateSystemUI() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? true;
    // Theme is controlled by main.dart
  }

  @override
  void dispose() {
    _displayController.dispose();
    _displayFocusNode.dispose();
    super.dispose();
  }

  void _onDisplayChanged() {
    String text = _displayController.text;
    if (text.isEmpty) text = '0';
    _baseAmount = double.tryParse(text.replaceAll(',', '')) ?? 0;
    _updateCalculation();
  }

  void _onNumberPressed(String value) {
    String current = _displayController.text;
    if (current == '0') {
      _displayController.text = value;
    } else {
      _displayController.text = current + value;
    }
    _displayController.selection = TextSelection.fromPosition(
      TextPosition(offset: _displayController.text.length),
    );
    _updateCalculation();
  }

  void _onDecimalPressed() {
    final text = _displayController.text;
    if (!text.contains('.')) {
      _displayController.text = text + '.';
      _displayController.selection = TextSelection.fromPosition(
        TextPosition(offset: _displayController.text.length),
      );
      _updateCalculation();
    }
  }

  void _onClearPressed() {
    setState(() {
      _displayController.text = '0';
      _baseAmount = 0;
      _updateCalculation();
    });
  }

  void _onBackspacePressed() {
    final current = _displayController.text;
    if (current.length <= 1 || current == '0') {
      _displayController.text = '0';
    } else {
      _displayController.text = current.substring(0, current.length - 1);
    }
    _displayController.selection = TextSelection.fromPosition(
      TextPosition(offset: _displayController.text.length),
    );
    _updateCalculation();
  }

  void _removeTaxFromPrice() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    double totalPrice = _baseAmount;
    if (totalPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a price first'),
          backgroundColor: redError,
        ),
      );
      return;
    }

    double activeServiceRate = _applyServiceCharge ? _serviceRate : 0;
    double taxMultiplier = 1 + (_gctRate / 100) + (activeServiceRate / 100);
    double basePrice = totalPrice / taxMultiplier;
    double taxAmount = totalPrice - basePrice;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Tax Removed',
            style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Original Price (with tax):',
                style: TextStyle(color: textGrey, fontSize: 14),
              ),
              Text(
                '$_currencySymbol${totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: textLight,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: borderColor),
              const SizedBox(height: 16),
              Text(
                'Base Price (without tax):',
                style: TextStyle(color: textGrey, fontSize: 14),
              ),
              Text(
                '$_currencySymbol${basePrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: const Color(0xFF00ff88),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tax Amount Removed:',
                style: TextStyle(color: textGrey, fontSize: 14),
              ),
              Text(
                '$_currencySymbol${taxAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: redError,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: textGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                _displayController.text = basePrice.toStringAsFixed(2);
                _updateCalculation();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              child: Text('Use Base Price'),
            ),
          ],
        );
      },
    );
  }

  void _addToCart() {
    if (_baseAmount > 0) {
      final itemBreakdown = _calculateBreakdownForAmount(_baseAmount);
      setState(() {
        _cartItems.add({
          'amount': _baseAmount,
          'name': 'Item ${_cartItems.length + 1}',
          'subtotal': itemBreakdown['subtotal']!,
          'gct': itemBreakdown['gct']!,
          'service': itemBreakdown['service']!,
          'discount': itemBreakdown['discount']!,
          'total': itemBreakdown['total']!,
        });
        _displayController.text = '0';
        _baseAmount = 0;
        _updateCalculation();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to cart: $_currencySymbol${itemBreakdown['total']!.toStringAsFixed(2)}',
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: primary,
        ),
      );
    }
  }

  Map<String, double> _calculateBreakdownForAmount(double amount) {
    if (amount <= 0) {
      return {
        'subtotal': 0.0,
        'gct': 0.0,
        'service': 0.0,
        'discount': 0.0,
        'total': 0.0,
      };
    }

    double subtotal = amount;
    double gct = 0;
    double service = 0;
    double discount = 0;

    if (_priceIncludesTax) {
      subtotal = amount / (1 + (_gctRate / 100));
      gct = amount - subtotal;
    } else {
      gct = (subtotal * _gctRate) / 100;
    }

    if (_applyServiceCharge && _serviceRate > 0) {
      service = (subtotal * _serviceRate) / 100;
    }

    double totalBeforeDiscount = subtotal + gct + service;

    if (_applyDiscount && _discountRate > 0) {
      if (_discountFirst) {
        discount = (subtotal * _discountRate) / 100;
        subtotal -= discount;
        if (!_priceIncludesTax) {
          gct = (subtotal * _gctRate) / 100;
        }
        if (_applyServiceCharge && _serviceRate > 0) {
          service = (subtotal * _serviceRate) / 100;
        }
      } else {
        discount = (totalBeforeDiscount * _discountRate) / 100;
      }
    }

    double total = (subtotal + gct + service - discount).clamp(
      0,
      double.infinity,
    );

    return {
      'subtotal': subtotal.clamp(0, double.infinity),
      'gct': gct.clamp(0, double.infinity),
      'service': service.clamp(0, double.infinity),
      'discount': discount.clamp(0, double.infinity),
      'total': total,
    };
  }

  Map<String, double> _calculateBreakdown() {
    if (_cartItems.isEmpty) {
      return _calculateBreakdownForAmount(_baseAmount);
    }

    double totalSubtotal = 0;
    double totalGct = 0;
    double totalService = 0;
    double totalDiscount = 0;
    double grandTotal = 0;

    for (var item in _cartItems) {
      totalSubtotal += item['subtotal'];
      totalGct += item['gct'];
      totalService += item['service'];
      totalDiscount += item['discount'];
      grandTotal += item['total'];
    }

    return {
      'subtotal': totalSubtotal,
      'gct': totalGct,
      'service': totalService,
      'discount': totalDiscount,
      'total': grandTotal,
    };
  }

  void _updateCalculation() {
    String text = _displayController.text;
    if (text.isEmpty) text = '0';
    _baseAmount = double.tryParse(text.replaceAll(',', '')) ?? 0;
    setState(() {});
  }

  void _showCountryPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Country',
                style: TextStyle(
                  color: textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ..._countryPresets.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key, style: TextStyle(color: textLight)),
                  subtitle: Text(
                    '${entry.value['name']} ${entry.value['tax']}%',
                    style: TextStyle(color: textGrey),
                  ),
                  trailing: _selectedCountry == entry.key
                      ? Icon(Icons.check, color: primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCountry = entry.key;
                      _gctRate = entry.value['tax'];
                      _currencySymbol = entry.value['currency'];
                      _updateCalculation();
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showRateInputPopup(
    String title,
    double currentRate,
    Function(double) onSet,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final TextEditingController rateController = TextEditingController(
      text: currentRate.toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Enter $title %',
            style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textLight, fontSize: 20),
            autofocus: true,
            decoration: InputDecoration(
              suffixText: '%',
              suffixStyle: TextStyle(color: textGrey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: textGrey!),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(rateController.text) ?? 0;
                onSet(val);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              child: Text('Set Rate'),
            ),
          ],
        );
      },
    );
  }

  void _showTaxRateEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    showDialog(
      context: context,
      builder: (context) {
        double tempGct = _gctRate;
        double tempService = _serviceRate;
        double tempDiscount = _discountRate;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardColor,
              title: Text('Adjust Rates', style: TextStyle(color: textLight)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRateSlider(
                    'GCT/VAT',
                    tempGct,
                    (value) => setDialogState(() => tempGct = value),
                  ),
                  const SizedBox(height: 20),
                  _buildRateSlider(
                    'Service',
                    tempService,
                    (value) => setDialogState(() => tempService = value),
                  ),
                  const SizedBox(height: 20),
                  _buildRateSlider(
                    'Discount',
                    tempDiscount,
                    (value) => setDialogState(() => tempDiscount = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _gctRate = tempGct;
                      _serviceRate = tempService;
                      _discountRate = tempDiscount;
                      _updateCalculation();
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRateSlider(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(1)}%',
          style: TextStyle(color: textLight),
        ),
        Slider(
          value: value,
          min: 0,
          max: 30,
          divisions: 60,
          activeColor: primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showCartSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shopping Cart',
                        style: TextStyle(
                          color: textLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: textLight),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _cartItems.isEmpty
                        ? Center(
                            child: Text(
                              'Cart is empty\n\nAdd items using the = button',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textGrey),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) {
                              final item = _cartItems[index];
                              return Card(
                                color: cardSurfaceColor,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ExpansionTile(
                                  title: Text(
                                    item['name'],
                                    style: TextStyle(
                                      color: textLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Base: $_currencySymbol${item['amount'].toStringAsFixed(2)}',
                                    style: TextStyle(color: textGrey),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$_currencySymbol${item['total'].toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'with tax',
                                            style: TextStyle(
                                              color: textGrey,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: redError,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _cartItems.removeAt(index);
                                            _updateCalculation();
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          _buildCartItemRow(
                                            'Subtotal',
                                            item['subtotal'],
                                          ),
                                          _buildCartItemRow(
                                            '${_countryPresets[_selectedCountry]!['name']} (${_gctRate.toStringAsFixed(0)}%)',
                                            item['gct'],
                                            color: redError,
                                          ),
                                          if (item['service'] > 0)
                                            _buildCartItemRow(
                                              'Service',
                                              item['service'],
                                              color: redError,
                                            ),
                                          if (item['discount'] > 0)
                                            _buildCartItemRow(
                                              'Discount',
                                              item['discount'],
                                              color: greenSuccess,
                                              isDiscount: true,
                                            ),
                                          Divider(color: borderColor),
                                          _buildCartItemRow(
                                            'Total',
                                            item['total'],
                                            color: primary,
                                            isBold: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (_cartItems.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _cartItems.clear();
                          _updateCalculation();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: redError,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text('Clear Cart'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartItemRow(
    String label,
    double amount, {
    Color? color,
    bool isDiscount = false,
    bool isBold = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textLight = isDark ? textLightDark : textLightLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final effectiveColor = color ?? textLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textGrey,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}$_currencySymbol${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: effectiveColor,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final breakdown = _calculateBreakdown();

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textLight),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Shopping Calc',
              style: TextStyle(
                color: textLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              GestureDetector(
                onTap: _showCountryPicker,
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cardSurfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedCountry == 'Jamaica'
                            ? '🇯🇲'
                            : _selectedCountry == 'USA'
                            ? '🇺🇸'
                            : _selectedCountry == 'UK'
                            ? '🇬🇧'
                            : _selectedCountry == 'Canada'
                            ? '🇨🇦'
                            : _selectedCountry == 'EU'
                            ? '🇪🇺'
                            : '🌍',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCountry == 'Jamaica'
                            ? 'JMD'
                            : _selectedCountry.substring(0, 2).toUpperCase(),
                        style: TextStyle(
                          color: textLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: textLight),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Total Amount Display
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(color: textGrey, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'REAL-TIME',
                            style: TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$_currencySymbol${breakdown['total']!.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: primary,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(color: borderColor),
                    const SizedBox(height: 8),
                    _buildBreakdownRow(
                      'Subtotal',
                      breakdown['subtotal']!,
                      textLight,
                    ),
                    const SizedBox(height: 8),
                    _buildBreakdownRow(
                      '${_countryPresets[_selectedCountry]!['name']} (${_gctRate.toStringAsFixed(0)}%)',
                      breakdown['gct']!,
                      redError,
                    ),
                    const SizedBox(height: 8),
                    if (_applyServiceCharge)
                      _buildBreakdownRow(
                        'Service (${_serviceRate.toStringAsFixed(0)}%)',
                        breakdown['service']!,
                        redError,
                      ),
                    if (_applyServiceCharge) const SizedBox(height: 8),
                    if (_applyDiscount)
                      _buildBreakdownRow(
                        'Discount (${_discountRate.toStringAsFixed(0)}%)',
                        breakdown['discount']!,
                        greenSuccess,
                        isDiscount: true,
                      ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: (breakdown['subtotal']! * 100).toInt(),
                              child: Container(
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00d4aa),
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: (breakdown['gct']! * 100).toInt(),
                              child: Container(
                                height: 8,
                                color: const Color(0xFFff6b35),
                              ),
                            ),
                            Expanded(
                              flex:
                                  ((breakdown['service']! > 0
                                              ? breakdown['service']!
                                              : 1) *
                                          100)
                                      .toInt(),
                              child: Container(
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF5b8def),
                                  borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Base',
                              style: TextStyle(color: textGrey, fontSize: 12),
                            ),
                            Text(
                              'Tax & Fees',
                              style: TextStyle(color: textGrey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // FIXED Toggle Section - Original size with two-row text
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Price Includes\nTax?',
                              textAlign: TextAlign.center,
                              textScaleFactor: 1.0,
                              style: TextStyle(
                                color: textLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _priceIncludesTax,
                                onChanged: (value) {
                                  setState(() {
                                    _priceIncludesTax = value;
                                    _updateCalculation();
                                  });
                                },
                                activeColor: primary,
                                inactiveThumbColor: textGrey,
                                inactiveTrackColor: cardSurfaceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Add\nService',
                              textAlign: TextAlign.center,
                              textScaleFactor: 1.0,
                              style: TextStyle(
                                color: textLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _applyServiceCharge,
                                onChanged: (value) {
                                  if (value) {
                                    _showRateInputPopup(
                                      'Service',
                                      _serviceRate,
                                      (val) {
                                        setState(() {
                                          _serviceRate = val;
                                          _applyServiceCharge = true;
                                          _updateCalculation();
                                        });
                                      },
                                    );
                                  } else {
                                    setState(() {
                                      _applyServiceCharge = false;
                                      _updateCalculation();
                                    });
                                  }
                                },
                                activeColor: primary,
                                inactiveThumbColor: textGrey,
                                inactiveTrackColor: cardSurfaceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Add\nDiscount',
                              textAlign: TextAlign.center,
                              textScaleFactor: 1.0,
                              style: TextStyle(
                                color: textLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _applyDiscount,
                                onChanged: (value) {
                                  if (value) {
                                    _showRateInputPopup(
                                      'Discount',
                                      _discountRate,
                                      (val) {
                                        setState(() {
                                          _discountRate = val;
                                          _applyDiscount = true;
                                          _updateCalculation();
                                        });
                                      },
                                    );
                                  } else {
                                    setState(() {
                                      _applyDiscount = false;
                                      _updateCalculation();
                                    });
                                  }
                                },
                                activeColor: primary,
                                inactiveThumbColor: textGrey,
                                inactiveTrackColor: cardSurfaceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Calculator Buttons - ONLY PADDING CHANGED
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalculatorButton(
                              'C',
                              onTap: _onClearPressed,
                              color: redError,
                            ),
                            _buildCalculatorButton(
                              '%',
                              onTap: _showTaxRateEditor,
                            ),
                            _buildCalculatorButton('/', onTap: () {}),
                            _buildCalculatorButton(
                              '',
                              icon: Icons.backspace_outlined,
                              onTap: _onBackspacePressed,
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalculatorButton(
                              '7',
                              onTap: () => _onNumberPressed('7'),
                            ),
                            _buildCalculatorButton(
                              '8',
                              onTap: () => _onNumberPressed('8'),
                            ),
                            _buildCalculatorButton(
                              '9',
                              onTap: () => _onNumberPressed('9'),
                            ),
                            _buildCalculatorButton(
                              '×',
                              onTap: () {},
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalculatorButton(
                              '4',
                              onTap: () => _onNumberPressed('4'),
                            ),
                            _buildCalculatorButton(
                              '5',
                              onTap: () => _onNumberPressed('5'),
                            ),
                            _buildCalculatorButton(
                              '6',
                              onTap: () => _onNumberPressed('6'),
                            ),
                            _buildCalculatorButton(
                              '-',
                              onTap: () {},
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalculatorButton(
                              '1',
                              onTap: () => _onNumberPressed('1'),
                            ),
                            _buildCalculatorButton(
                              '2',
                              onTap: () => _onNumberPressed('2'),
                            ),
                            _buildCalculatorButton(
                              '3',
                              onTap: () => _onNumberPressed('3'),
                            ),
                            _buildCalculatorButton(
                              '+',
                              onTap: () {},
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalculatorButton(
                              '🛒',
                              onTap: _cartItems.isEmpty
                                  ? _addToCart
                                  : _showCartSheet,
                              onLongPress: _removeTaxFromPrice,
                            ),
                            _buildCalculatorButton(
                              '0',
                              onTap: () => _onNumberPressed('0'),
                            ),
                            _buildCalculatorButton(
                              '.',
                              onTap: _onDecimalPressed,
                            ),
                            _buildCalculatorButton(
                              '=',
                              onTap: _addToCart,
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double amount,
    Color color, {
    bool isDiscount = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? textGreyDark : textGreyLight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textGrey, fontSize: 14)),
        Text(
          '${isDiscount ? '-' : '+'}$_currencySymbol${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatorButton(
    String text, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Color? color,
    double fontSize = 20,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        child: Material(
          color: cardSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: color ?? textLight, size: fontSize + 4)
                    : Text(
                        text,
                        style: TextStyle(
                          color: color ?? textLight,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
