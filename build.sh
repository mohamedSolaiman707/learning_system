#!/bin/bash

# تحميل Flutter SDK إذا لم يكن موجوداً
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter
fi

# إضافة Flutter إلى المسار
export PATH="$PATH:`pwd`/flutter/bin"

# بناء نسخة الويب مع تمرير المتغيرات
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=LIVEKIT_URL=$LIVEKIT_URL
