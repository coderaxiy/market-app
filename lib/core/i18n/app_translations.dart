// Strings the mobile app needs that the storefront dictionary (`translations.dart`,
// generated from emarket's locale files) doesn't have. Same `namespace.name` keys and
// `{param}` placeholders. If the storefront later adds a key with the same name, its
// value wins: delete the duplicate here.

const appEn = <String, String>{
  'checkout.lastUsedNote': 'You picked this point last time.',
  'checkout.editPoint': 'Change pickup point',
  'checkout.hoursUnknown': 'Hours not listed',
  'checkout.pointPhone': 'Phone: {phone}',
  'auth.forgotPassword': 'Forgot password?',
  'auth.resetTitle': 'Reset password',
  'auth.resetSubtitle': 'Enter your email and we’ll send you a 6-digit code.',
  'auth.sendCode': 'Send code',
  'auth.requestFailed': 'Couldn’t send the code. Please try again.',
  'auth.resetCodeTitle': 'Enter the code',
  'auth.resetCodeSubtitle': 'If an account exists for {email}, we sent a 6-digit code. It works for 15 minutes.',
  'auth.code': 'Code',
  'auth.codeInvalid': 'Enter the 6-digit code',
  'auth.newPassword': 'New password',
  'auth.passwordTooShort': 'Use 8 to 72 characters',
  'auth.resetSubmit': 'Change password',
  'auth.resetFailed': 'Couldn’t change the password. Please try again.',
  'auth.resetDone': 'Password changed. Sign in with your new password.',
  'auth.sendAgain': 'Send a new code',
  'auth.backToLogin': 'Back to sign in',
};

const appUz = <String, String>{
  'checkout.lastUsedNote': 'Bu punktni oxirgi marta ham tanlagansiz.',
  'checkout.editPoint': 'Topshirish punktini almashtirish',
  'checkout.hoursUnknown': 'Ish vaqti koʻrsatilmagan',
  'checkout.pointPhone': 'Telefon: {phone}',
  'auth.forgotPassword': 'Parolni unutdingizmi?',
  'auth.resetTitle': 'Parolni tiklash',
  'auth.resetSubtitle': 'Emailingizni kiriting, biz 6 xonali kod yuboramiz.',
  'auth.sendCode': 'Kodni yuborish',
  'auth.requestFailed': 'Kodni yuborib boʻlmadi. Qayta urinib koʻring.',
  'auth.resetCodeTitle': 'Kodni kiriting',
  'auth.resetCodeSubtitle': '{email} uchun hisob mavjud boʻlsa, 6 xonali kod yuborildi. Kod 15 daqiqa amal qiladi.',
  'auth.code': 'Kod',
  'auth.codeInvalid': '6 xonali kodni kiriting',
  'auth.newPassword': 'Yangi parol',
  'auth.passwordTooShort': 'Parol 8 dan 72 gacha belgidan iborat boʻlsin',
  'auth.resetSubmit': 'Parolni oʻzgartirish',
  'auth.resetFailed': 'Parolni oʻzgartirib boʻlmadi. Qayta urinib koʻring.',
  'auth.resetDone': 'Parol oʻzgartirildi. Yangi parol bilan kiring.',
  'auth.sendAgain': 'Yangi kod yuborish',
  'auth.backToLogin': 'Kirishga qaytish',
};

const appRu = <String, String>{
  'checkout.lastUsedNote': 'Вы выбирали этот пункт в прошлый раз.',
  'checkout.editPoint': 'Сменить пункт выдачи',
  'checkout.hoursUnknown': 'Часы работы не указаны',
  'checkout.pointPhone': 'Телефон: {phone}',
  'auth.forgotPassword': 'Забыли пароль?',
  'auth.resetTitle': 'Восстановление пароля',
  'auth.resetSubtitle': 'Введите email, и мы отправим 6-значный код.',
  'auth.sendCode': 'Отправить код',
  'auth.requestFailed': 'Не удалось отправить код. Попробуйте ещё раз.',
  'auth.resetCodeTitle': 'Введите код',
  'auth.resetCodeSubtitle': 'Если для {email} есть аккаунт, мы отправили 6-значный код. Он действует 15 минут.',
  'auth.code': 'Код',
  'auth.codeInvalid': 'Введите 6-значный код',
  'auth.newPassword': 'Новый пароль',
  'auth.passwordTooShort': 'От 8 до 72 символов',
  'auth.resetSubmit': 'Сменить пароль',
  'auth.resetFailed': 'Не удалось сменить пароль. Попробуйте ещё раз.',
  'auth.resetDone': 'Пароль изменён. Войдите с новым паролем.',
  'auth.sendAgain': 'Отправить новый код',
  'auth.backToLogin': 'Назад ко входу',
};

const appTranslations = <String, Map<String, String>>{
  'en': appEn,
  'uz': appUz,
  'ru': appRu,
};
