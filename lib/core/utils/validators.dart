class Validators {
  Validators._();

  static final RegExp _companyCodeRegex = RegExp(r'^[A-Z]{2,5}-\d{4}$');

  static bool isValidCompanyCode(String code) {
    return _companyCodeRegex.hasMatch(code.trim().toUpperCase());
  }

  static String? validateCompanyCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código de empresa es requerido';
    }
    if (!isValidCompanyCode(value)) {
      return 'Formato inválido. Ejemplo: LCC-2026';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  static String? validateMaxLength(
    String? value,
    int maxLength,
    String fieldName,
  ) {
    if (value != null && value.length > maxLength) {
      return '$fieldName no puede exceder $maxLength caracteres';
    }
    return null;
  }
}
