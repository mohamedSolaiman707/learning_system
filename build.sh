#!/bin/bash

# 1. تحميل Flutter SDK في مجلد مؤقت خارج مجلد المشروع لتجنب المشاكل
if [ ! -d "../flutter" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 ../flutter
fi

# 2. إضافة Flutter إلى المسار
export PATH="$PATH:`pwd`/../flutter/bin"

# 3. جلب المكتبات
echo "Fetching dependencies..."
flutter pub get

# 4. بناء نسخة الويب
echo "Building Web application..."
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=LIVEKIT_URL=$LIVEKIT_URL
