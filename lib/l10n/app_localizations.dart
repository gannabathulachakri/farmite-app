import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('te')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Farmite'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @farmers.
  ///
  /// In en, this message translates to:
  /// **'Farmers'**
  String get farmers;

  /// No description provided for @stockEntry.
  ///
  /// In en, this message translates to:
  /// **'Stock Entry'**
  String get stockEntry;

  /// No description provided for @bills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get bills;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @totalFarmers.
  ///
  /// In en, this message translates to:
  /// **'Total Farmers'**
  String get totalFarmers;

  /// No description provided for @totalStock.
  ///
  /// In en, this message translates to:
  /// **'Total Stock (Bags)'**
  String get totalStock;

  /// No description provided for @todayRevenue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Revenue'**
  String get todayRevenue;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivityYet;

  /// No description provided for @startByAddingFarmer.
  ///
  /// In en, this message translates to:
  /// **'Start by adding a farmer and then add some stock.'**
  String get startByAddingFarmer;

  /// No description provided for @addFarmer.
  ///
  /// In en, this message translates to:
  /// **'Add Farmer'**
  String get addFarmer;

  /// No description provided for @searchFarmers.
  ///
  /// In en, this message translates to:
  /// **'Search farmers...'**
  String get searchFarmers;

  /// No description provided for @noFarmersFound.
  ///
  /// In en, this message translates to:
  /// **'No farmers found.'**
  String get noFarmersFound;

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'Add Stock'**
  String get addStock;

  /// No description provided for @selectFarmer.
  ///
  /// In en, this message translates to:
  /// **'Select Farmer'**
  String get selectFarmer;

  /// No description provided for @selectVegetable.
  ///
  /// In en, this message translates to:
  /// **'Select Vegetable'**
  String get selectVegetable;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @bags.
  ///
  /// In en, this message translates to:
  /// **'Bags'**
  String get bags;

  /// No description provided for @oldBags.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get oldBags;

  /// No description provided for @newBags.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newBags;

  /// No description provided for @kgs.
  ///
  /// In en, this message translates to:
  /// **'KGs'**
  String get kgs;

  /// No description provided for @oldKgs.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get oldKgs;

  /// No description provided for @newKgs.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newKgs;

  /// No description provided for @totalKgs.
  ///
  /// In en, this message translates to:
  /// **'Total KGs'**
  String get totalKgs;

  /// No description provided for @addPriceRow.
  ///
  /// In en, this message translates to:
  /// **'Add Row'**
  String get addPriceRow;

  /// No description provided for @soldBags.
  ///
  /// In en, this message translates to:
  /// **'Sold Bags'**
  String get soldBags;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get transport;

  /// No description provided for @otherCharges.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherCharges;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grandTotal;

  /// No description provided for @generateBill.
  ///
  /// In en, this message translates to:
  /// **'Generate Bill'**
  String get generateBill;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this data?'**
  String get confirmDelete;

  /// No description provided for @deleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data deleted successfully'**
  String get deleteSuccess;

  /// No description provided for @sendBill.
  ///
  /// In en, this message translates to:
  /// **'Send Bill'**
  String get sendBill;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get noRecordsYet;

  /// No description provided for @generateABill.
  ///
  /// In en, this message translates to:
  /// **'Generate a bill to see it in your history.'**
  String get generateABill;

  /// No description provided for @payableAmount.
  ///
  /// In en, this message translates to:
  /// **'Payable Amount'**
  String get payableAmount;

  /// No description provided for @finalPayableCapital.
  ///
  /// In en, this message translates to:
  /// **'Final Payable Capital'**
  String get finalPayableCapital;

  /// No description provided for @generatedVia.
  ///
  /// In en, this message translates to:
  /// **'Generated via Farmite App'**
  String get generatedVia;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @telugu.
  ///
  /// In en, this message translates to:
  /// **'Telugu'**
  String get telugu;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllData;

  /// No description provided for @clearDataWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: This action cannot be undone.'**
  String get clearDataWarning;

  /// No description provided for @farmerName.
  ///
  /// In en, this message translates to:
  /// **'Farmer Name'**
  String get farmerName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (Optional)'**
  String get phoneNumber;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @viewBill.
  ///
  /// In en, this message translates to:
  /// **'View Bill'**
  String get viewBill;

  /// No description provided for @billDetails.
  ///
  /// In en, this message translates to:
  /// **'Bill Details'**
  String get billDetails;

  /// No description provided for @editBill.
  ///
  /// In en, this message translates to:
  /// **'Edit Bill'**
  String get editBill;

  /// No description provided for @printPdf.
  ///
  /// In en, this message translates to:
  /// **'Print / PDF'**
  String get printPdf;

  /// No description provided for @remainingKgs.
  ///
  /// In en, this message translates to:
  /// **'Remaining KGs'**
  String get remainingKgs;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @finalBillAmount.
  ///
  /// In en, this message translates to:
  /// **'Final Bill Amount'**
  String get finalBillAmount;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Farmite VEGETABLES & ONIONS - BHIMAVARAM'**
  String get companyName;

  /// No description provided for @proprietor.
  ///
  /// In en, this message translates to:
  /// **'Prop. Satyababu. 9989072773'**
  String get proprietor;

  /// No description provided for @farmerPrefix.
  ///
  /// In en, this message translates to:
  /// **'Sri'**
  String get farmerPrefix;

  /// No description provided for @expenditure.
  ///
  /// In en, this message translates to:
  /// **'Expenditure'**
  String get expenditure;

  /// No description provided for @kirayee.
  ///
  /// In en, this message translates to:
  /// **'KIRAYEE'**
  String get kirayee;

  /// No description provided for @kooli.
  ///
  /// In en, this message translates to:
  /// **'KOOLI'**
  String get kooli;

  /// No description provided for @commission.
  ///
  /// In en, this message translates to:
  /// **'COMMISSION'**
  String get commission;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @bagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bags'**
  String get bagsLabel;

  /// No description provided for @kgLabel.
  ///
  /// In en, this message translates to:
  /// **'Kg'**
  String get kgLabel;

  /// No description provided for @rsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rs'**
  String get rsLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @farmerLabel.
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get farmerLabel;

  /// No description provided for @pricingDetails.
  ///
  /// In en, this message translates to:
  /// **'Pricing Details'**
  String get pricingDetails;

  /// No description provided for @netValue.
  ///
  /// In en, this message translates to:
  /// **'Net Value'**
  String get netValue;

  /// No description provided for @storageBags.
  ///
  /// In en, this message translates to:
  /// **'Storage Bags'**
  String get storageBags;

  /// No description provided for @storageKgs.
  ///
  /// In en, this message translates to:
  /// **'Storage KGs'**
  String get storageKgs;

  /// No description provided for @totalPayable.
  ///
  /// In en, this message translates to:
  /// **'TOTAL PAYABLE'**
  String get totalPayable;

  /// No description provided for @importCharge.
  ///
  /// In en, this message translates to:
  /// **'Import Charge'**
  String get importCharge;

  /// No description provided for @step1.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Farmer & Item'**
  String get step1;

  /// No description provided for @step2.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Inbound Stock'**
  String get step2;

  /// No description provided for @step3.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Sale Details'**
  String get step3;

  /// No description provided for @step4.
  ///
  /// In en, this message translates to:
  /// **'Step 4: Inventory Status'**
  String get step4;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @totalBags.
  ///
  /// In en, this message translates to:
  /// **'Total Bags'**
  String get totalBags;

  /// No description provided for @remainingBags.
  ///
  /// In en, this message translates to:
  /// **'Remaining Bags'**
  String get remainingBags;

  /// No description provided for @remainingKgsLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining KGs'**
  String get remainingKgsLabel;

  /// No description provided for @noAdditionalExpenses.
  ///
  /// In en, this message translates to:
  /// **'No additional expenses'**
  String get noAdditionalExpenses;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @editRecord.
  ///
  /// In en, this message translates to:
  /// **'Edit Record'**
  String get editRecord;

  /// No description provided for @newCages.
  ///
  /// In en, this message translates to:
  /// **'New Cages'**
  String get newCages;

  /// No description provided for @damages.
  ///
  /// In en, this message translates to:
  /// **'Damages (KGs)'**
  String get damages;

  /// No description provided for @cooliePerBag.
  ///
  /// In en, this message translates to:
  /// **'Coolie / Bag'**
  String get cooliePerBag;

  /// No description provided for @stockLimitError.
  ///
  /// In en, this message translates to:
  /// **'Sold stock cannot be more than imported stock.'**
  String get stockLimitError;

  /// No description provided for @pricingError.
  ///
  /// In en, this message translates to:
  /// **'Please enter pricing for sold KGs.'**
  String get pricingError;

  /// No description provided for @saveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get saveSuccess;

  /// No description provided for @updateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Updated successfully'**
  String get updateSuccess;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @dataCleared.
  ///
  /// In en, this message translates to:
  /// **'Data cleared'**
  String get dataCleared;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
