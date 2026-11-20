# Soundify

اپلیکیشن استریم موسیقی با Flutter (Android) متصل به API درس: `https://soundify.easyfound.ir/api/v1`

## پیش‌نیازها
- Flutter stable (ساخته‌شده با 3.50.1 / Dart 3.13)
- Android SDK (platform 36، build-tools 36) و JDK 17 یا بالاتر
- گوشی اندرویدی با اثر انگشت/چهره برای تست بیومتریک (arm64-v8a)

## اجرا
```sh
flutter pub get
flutter run                                              # روی گوشی متصل
flutter build apk --release --target-platform android-arm64
# خروجی: build/app/outputs/flutter-apk/app-release.apk
```
اگر RAM کم است: `org.gradle.jvmargs` در `android/gradle.properties` را کم کنید (در این پروژه 1.5 GB).

## کتابخانه‌ها
| کتابخانه | کاربرد |
|---|---|
| dio | کلاینت شبکه، تایم‌اوت، اینترسپتور تمدید توکن |
| flutter_secure_storage | ذخیره امن Access/Refresh Token (Keystore) |
| local_auth | ورود بیومتریک |
| just_audio | پخش استریم (HTTP 206) |
| just_audio_background | پخش پس‌زمینه، اعلان رسانه و صفحه قفل |
| shared_preferences | فقط پرچم «صفحه خوش‌آمدگویی دیده شد» (هیچ توکنی اینجا نیست) |
| provider | مدیریت وضعیت (ChangeNotifier) |

## ساختار
```
lib/
  core/        api_client (Dio + interceptor)، token_storage، models، security، widgets
  features/
    auth/        auth_provider، صفحات ورود/ثبت‌نام/OTP/فراموشی/قفل بیومتریک
    onboarding/  splash و onboarding (فقط اجرای اول)
    home/        shell (ناوبری پایین + مینی‌پلیر) و صفحه خانه
    search/      جست‌وجوی زنده با Debounce
    library/     پلی‌لیست‌ها (CRUD) و علاقه‌مندی‌ها
    player/      player_provider، مینی‌پلیر، پلیر تمام‌صفحه با اکولایزر
    profile/     پروفایل و تنظیمات امنیتی
android/.../MainActivity.kt   بررسی root/emulator (MethodChannel) + درخواست مجوز اعلان
```

## نکات پیاده‌سازی
- **توکن‌ها** فقط در `flutter_secure_storage`. Interceptor با 401 یک بار `/auth/token/refresh` را (با قفل برای درخواست‌های هم‌زمان) صدا می‌زند و درخواست را تکرار می‌کند؛ فقط اگر refresh رد شود کاربر خارج می‌شود (خطای شبکه باعث خروج نمی‌شود).
- **بیومتریک**: با فعال‌سازی در پروفایل، نشست روی دستگاه می‌ماند و هنگام باز کردن برنامه (یا «قفل کردن برنامه») با اثر انگشت/چهره باز می‌شود.
- **OTP**: درخواست کد، شمارش معکوس ارسال مجدد (از `resend_after` سرور)، تأیید. بعد از ثبت‌نام، کد تأیید همان صفحه است و پس از تأیید خودکار وارد می‌شود.
- **جست‌وجو**: Debounce ‏450ms، ادغام نتایج `q` و `artist`، و نادیده گرفتن پاسخ‌های قدیمی.
- **علاقه‌مندی**: لایک/آن‌لایک خوش‌بینانه (optimistic) و در صورت خطا برگشت.
- **پخش**: یک صف `just_audio` با `MediaItem` برای اعلان؛ Next/Previous و پایان آهنگ خودکار.
- **پایداری پخش**: اگر استریم یک آهنگ کند یا قطع شود، پلیر یک بار دوباره تلاش می‌کند و سپس به آهنگ بعدی می‌رود؛ پخش هرگز روی «در حال اتصال» نمی‌ماند.
- **اعلان رسانه**: آیکون‌های دکمه‌ها با `res/raw/keep.xml` از حذف توسط R8 در نسخه release محافظت شده‌اند (بدون آن، اعلان در release ساخته نمی‌شود).
- **امنیت دستگاه**: بررسی su/Magisk/test-keys و اثر انگشت سازنده شبیه‌ساز؛ نتیجه در صفحه پروفایل و بنر هشدار.

## یادداشت درباره API
- سند API (`/schema`) مسیر `PATCH /playlists/{id}` برای ویرایش نام/توضیحات دارد (در جدول صورت پروژه نبود) و استفاده شده است.
- در سند واقعی، `GET /tracks` و `/tracks/featured` نیاز به توکن دارند؛ برنامه همیشه Bearer می‌فرستد.
- `POST /auth/otp/verify` طبق سند فقط `verified` برمی‌گرداند (نه توکن). اگر سرور توکن هم بدهد برنامه آن را می‌پذیرد، وگرنه کاربر با رمز وارد می‌شود (بعد از ثبت‌نام خودکار).
- امضای release با کلید debug است (برای تحویل آموزشی کافی است).
