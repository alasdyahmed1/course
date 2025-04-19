-- 2. إنشاء الجدول مع ضبط التوقيت
create table auth_users (
    id uuid primary key references auth.users on delete cascade,
    email text unique not null,
    device_id text null,
    device_platform text null check (device_platform in ('web', 'android', 'ios', 'windows', 'macos', 'linux')),
    verification_completed boolean default false,
    created_at timestamp with time zone default (timezone('Asia/Baghdad', now())),
    last_sign_in timestamp with time zone
);

-- 3. دالة إنشاء سجل المستخدم الأولي (بدون معلومات الجهاز)
create or replace function create_initial_user_record(
    user_id uuid,
    user_email text
)
returns void as $$
begin
    insert into auth_users (
        id,
        email,
        verification_completed,
        created_at
    ) values (
        user_id,
        user_email,
        false,
        timezone('Asia/Baghdad', now())
    );
end;
$$ language plpgsql security definer;

-- 4. دالة تحديث معلومات الجهاز بعد التحقق
create or replace function update_device_info(
    user_id uuid,
    device_identifier text,
    p_platform text
)
returns void as $$
begin
    update auth_users
    set 
        device_id = device_identifier,
        device_platform = p_platform,
        verification_completed = true
    where id = user_id;
end;
$$ language plpgsql security definer;

-- 5. تبسيط دالة تنظيف السجلات غير المؤكدة
create or replace function cleanup_unverified_users()
returns void as $$
begin
    -- حذف المستخدمين من auth.users مباشرة
    -- سيتم حذف السجلات تلقائياً من auth_users بسبب قيد ON DELETE CASCADE
    delete from auth.users
    where id in (
        select id from auth_users
        where verification_completed = false
        and timezone('Asia/Baghdad', now()) > (created_at + interval '1 hour')
    );
end;
$$ language plpgsql security definer;

-- إضافة الصلاحيات المطلوبة للدالة
grant delete on auth.users to service_role;

-- 6. دالة تسجيل الدخول وتحديث آخر وقت
create or replace function record_signin(
    user_id uuid,
    device_identifier text,
    p_platform text
)
returns boolean as $$
declare
    user_verified boolean;
begin
    select verification_completed into user_verified
    from auth_users
    where id = user_id
    and device_id = device_identifier
    and device_platform = p_platform;

    if user_verified then
        update auth_users
        set last_sign_in = timezone('Asia/Baghdad', now())
        where id = user_id;
        return true;
    end if;

    return false;
end;
$$ language plpgsql security definer;

-- 7. إضافة Cron Job لتنظيف السجلات (يتطلب pg_cron extension)
select cron.schedule(
    'cleanup-unverified-users',
    '*/15 * * * *', -- كل 15 دقيقة
    'select cleanup_unverified_users();'
);

-- 8. إضافة Indexes للأداء
create index idx_auth_users_email on auth_users(email);
create index idx_auth_users_device on auth_users(device_id, device_platform);
create index idx_auth_users_verification on auth_users(verification_completed, created_at);

-- 9. تفعيل RLS وإضافة السياسات الأمنية
alter table auth_users enable row level security;

create policy "Public email check"
    on auth_users for select
    using (true);

create policy "Enable insert for service role"
    on auth_users for insert
    with check (true);

create policy "Enable update for users"
    on auth_users for update
    using (auth.uid() = id);



-- الأقسام (مثل علوم الحاسوب، نظم المعلومات، الأنظمة الطبية، الأمن السيبراني)
create table departments (
  id uuid default uuid_generate_v4() primary key,
  name text not null,                              -- اسم القسم
  code text not null unique,                       -- رمز القسم (مثل CS, IS, MS, CY)
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- المراحل الدراسية (الأولى إلى الرابعة)
create table stages (
  id uuid default uuid_generate_v4() primary key,
  name text not null,                             -- اسم المرحلة
  level int not null check (level between 1 and 4), -- رقم المرحلة (1-4)
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- الفصول الدراسية (كل مرحلة لها فصلين)
create table semesters (
  id uuid default uuid_generate_v4() primary key,
  name text not null,                             -- اسم الفصل الدراسي
  stage_id uuid references stages(id) not null,    -- المرحلة
  department_id uuid references departments(id) not null, -- القسم
  semester_number int not null check (semester_number in (1, 2)), -- رقم الفصل (1 أو 2)
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- المواد الدراسية
create table courses (
  id uuid default uuid_generate_v4() primary key,
  title text not null,                            -- عنوان المادة
  description text,                               -- وصف المادة
  thumbnail_url text,                             -- رابط الصورة المصغرة
  semester_id uuid references semesters(id) not null, -- الفصل الدراسي
  total_videos int default 0,                     -- إجمالي عدد الفيديوهات
  total_duration int default 0,                   -- إجمالي مدة الكورس بالدقائق
  rating decimal(3,2) default 0.00,               -- متوسط التقييم
  ratings_count int default 0,                    -- عدد التقييمات
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- فيديوهات المواد
create table course_videos (
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references courses(id) not null,  -- المادة التي ينتمي إليها الفيديو
  title text not null,                            -- عنوان الفيديو
  description text,                               -- وصف الفيديو
  video_id text not null,                         -- معرف الفيديو في Bunny.net
  duration int not null,                          -- مدة الفيديو بالثواني
  order_number int not null,                      -- ترتيب الفيديو في المادة
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ملفات المواد (المرفقات مع كل فيديو)
create table course_files (
  id uuid default uuid_generate_v4() primary key,
  video_id uuid references course_videos(id) not null, -- الفيديو المرتبط
  title text not null,                         -- عنوان الملف
  description text,                            -- وصف الملف
  file_id text not null,                      -- معرف الملف في Bunny.net
  file_type text not null,                    -- نوع الملف (pdf, docx, etc)
  file_size bigint not null,                  -- حجم الملف بالبايت
  download_count int default 0,               -- عدد مرات التحميل
  order_number int not null,                  -- ترتيب الملف
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- تقييمات المواد
create table course_ratings (
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references courses(id) not null,  -- المادة التي تم تقييمها
  user_id uuid references auth.users(id) not null, -- المستخدم الذي قام بالتقييم
  rating int not null check (rating between 1 and 5), -- التقييم من 1 إلى 5
  comment text,                                   -- تعليق المستخدم
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(course_id, user_id)                      -- منع تكرار تقييم نفس المستخدم
);

-- تتبع تقدم الطلاب في المواد
create table course_progress (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users(id) not null,
  course_id uuid references courses(id) not null,
  total_watched_videos int default 0,          -- عدد الفيديوهات المشاهدة
  total_watched_duration int default 0,        -- إجمالي وقت المشاهدة بالثواني
  last_watched_video_id uuid,                  -- آخر فيديو تمت مشاهدته
  completion_percentage decimal(5,2) default 0, -- نسبة الإكمال
  is_completed boolean default false,          -- هل أكمل المادة
  last_watched_at timestamp with time zone,    -- آخر وقت مشاهدة
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, course_id)                   -- منع تكرار السجل
);

-- تتبع تقدم الطلاب في كل فيديو
create table video_progress (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users(id) not null,
  video_id uuid references course_videos(id) not null,
  watch_duration int default 0,                -- مدة المشاهدة بالثواني
  is_completed boolean default false,          -- هل أكمل الفيديو
  watch_percentage decimal(5,2) default 0,     -- نسبة المشاهدة
  last_position int default 0,                 -- آخر موضع في الفيديو بالثواني
  watched_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, video_id)                    -- منع تكرار السجل
);

-- تتبع الفيديوهات المحملة
create table downloaded_videos (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users(id) not null,
  video_id uuid references course_videos(id) not null,
  local_path text not null,                     -- مسار التخزين المحلي المشفر
  download_date timestamp with time zone default timezone('utc'::text, now()) not null,
  last_watched timestamp with time zone,        -- آخر مشاهدة للنسخة المحملة
  is_valid boolean default true,                -- هل النسخة المحملة صالحة
  encryption_key text not null,                 -- مفتاح تشفير الفيديو المحلي
  unique(user_id, video_id)                     -- منع تكرار التحميل
);
-- ================================================
-- 1. جداول الكورسات المدفوعة
-- ================================================
create table course_pricing (
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references courses(id) not null,
  price decimal(10,2) not null check (price >= 0),
  discount_price decimal(10,2),
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(course_id)  -- كل كورس له سعر واحد فقط
);

create table course_purchases (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users(id) not null,
  course_id uuid references courses(id) not null,
  amount_paid decimal(10,2) not null,
  payment_method text not null,
  payment_status text not null check (payment_status in ('pending', 'completed', 'failed', 'refunded')),
  transaction_id text unique,
  purchased_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, course_id) -- منع شراء نفس الكورس مرتين
);

create table course_access (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users(id) not null,
  course_id uuid references courses(id) not null,
  granted_by uuid references auth.users(id), -- في حال تم منح الوصول من قبل المسؤول
  access_type text not null check (access_type in ('purchased', 'granted')),
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, course_id)
);

-- ================================================
-- 2. تفعيل RLS على جميع الجداول
-- ================================================
alter table departments enable row level security;
alter table stages enable row level security;
alter table semesters enable row level security;
alter table courses enable row level security;
alter table course_videos enable row level security;
alter table course_files enable row level security;
alter table course_ratings enable row level security;
alter table course_progress enable row level security;
alter table video_progress enable row level security;
alter table downloaded_videos enable row level security;
alter table course_pricing enable row level security;
alter table course_purchases enable row level security;
alter table course_access enable row level security;

-- ================================================
-- 3. دالة التحقق من المسؤول
-- ================================================
create or replace function is_admin()
returns boolean
language plpgsql
security definer
as $$
declare
  admin_id uuid;
begin
  -- الحصول على معرف المسؤول مباشرة
  select id into admin_id
  from auth.users
  where email = 'alasdyahmed1@gmail.com'
  limit 1;
  
  return auth.uid() = admin_id;
end;
$$;

-- ================================================
-- 4. دالة التحقق من الوصول للكورس (تصحيح المشكلة التحويل)
-- ================================================
create or replace function has_course_access(p_course_id uuid)
returns boolean
language plpgsql
security definer
as $$
declare
  is_admin_user boolean;
begin
  -- التحقق من المسؤول أولاً
  select (auth.jwt()->>'email' = 'alasdyahmed1@gmail.com') into is_admin_user;
  
  if is_admin_user then
    return true;
  end if;

  -- التحقق من وجود صلاحية وصول
  return exists (
    select 1 
    from course_access
    where user_id = (auth.uid()::uuid)  -- تحويل صريح إلى UUID
    and course_id = p_course_id::uuid   -- تأكيد أن المعامل من نوع UUID
    and is_active = true
  );
end;
$$;

-- ================================================
-- 5. سياسات القراءة العامة
-- ================================================
create policy "محتوى الأقسام متاح للجميع" on departments for select using (true);
create policy "محتوى المراحل متاح للجميع" on stages for select using (true);
create policy "محتوى الفصول متاح للجميع" on semesters for select using (true);
create policy "محتوى الكورسات متاح للجميع" on courses for select using (true);
create policy "عرض أسعار الكورسات" on course_pricing for select using (true);

-- ================================================
-- 6. سياسات المحتوى المقيد (تحديث السياسات)
-- ================================================
-- حذف السياسات القديمة أولاً لتجنب التعارض
drop policy if exists "الوصول للفيديوهات" on course_videos;
create policy "الوصول للفيديوهات"
  on course_videos for select
  using (has_course_access(id)); -- استخدام id مباشرة لأنه uuid

drop policy if exists "الوصول للملفات" on course_files;
create policy "الوصول للملفات"
  on course_files for select
  using (has_course_access(
    (select id from course_videos where id = video_id::uuid)  -- تحويل video_id إلى uuid
  ));

-- ================================================
-- 7. سياسات المسؤول
-- ================================================
create policy "تعديل الأقسام" on departments for all using (is_admin());
create policy "تعديل المراحل" on stages for all using (is_admin());
create policy "تعديل الفصول" on semesters for all using (is_admin());
create policy "تعديل الكورسات" on courses for all using (is_admin());
create policy "تعديل الفيديوهات" on course_videos for all using (is_admin());
create policy "تعديل الملفات" on course_files for all using (is_admin());
create policy "تعديل الأسعار" on course_pricing for all using (is_admin());
create policy "منح الوصول للكورسات" on course_access for all using (is_admin());

-- ================================================
-- 8. سياسات المستخدم (تصحيح مشكلة تحويل الأنواع)
-- ================================================
create policy "تقدم المستخدم" 
  on course_progress for all 
  using (auth.uid() = id);  -- auth.uid() يعود UUID مباشرة في Supabase

create policy "تقدم الفيديو" 
  on video_progress for all 
  using (auth.uid() = user_id);

create policy "تحميلات المستخدم" 
  on downloaded_videos for all 
  using (auth.uid() = user_id);

create policy "مشتريات المستخدم" 
  on course_purchases for all 
  using (auth.uid() = user_id);

create policy "وصول المستخدم" 
  on course_access for select 
  using (auth.uid() = user_id);

-- ================================================
-- 9. سياسات التقييمات
-- ================================================
create policy "عرض التقييمات" on course_ratings for select using (true);
create policy "إضافة تقييم" on course_ratings for insert with check (auth.uid() = user_id);
create policy "تعديل التقييم" on course_ratings for update using (auth.uid() = user_id);

-- ================================================
-- 10. Triggers للتحديث التلقائي
-- ================================================
create or replace function update_course_stats()
returns trigger as $$
begin
  update courses
  set 
    rating = (select coalesce(avg(rating)::decimal(3,2), 0.00) from course_ratings where course_id = new.course_id),
    ratings_count = (select count(*) from course_ratings where course_id = new.course_id)
  where id = new.course_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_rating_change
  after insert or update or delete
  on course_ratings
  for each row
  execute function update_course_stats();

create or replace function update_course_completion()
returns trigger as $$
begin
  update course_progress cp
  set 
    completion_percentage = (
      select (count(vp.id)::decimal * 100 / nullif(c.total_videos, 0))::decimal(5,2)
      from video_progress vp
      join course_videos cv on cv.id = vp.video_id
      join courses c on c.id = cv.course_id
      where vp.user_id = new.user_id
      and c.id = cp.course_id
      and vp.is_completed = true
    ),
    total_watched_videos = (
      select count(*)
      from video_progress vp
      join course_videos cv on cv.id = vp.video_id
      where vp.user_id = new.user_id
      and cv.course_id = cp.course_id
      and vp.is_completed = true
    ),
    updated_at = now()
  where cp.user_id = new.user_id
  and cp.course_id = (select course_id from course_videos where id = new.video_id);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_video_progress_change
  after insert or update
  on video_progress
  for each row
  execute function update_course_completion();

-- ================================================
-- 11. Indexes للأداء
-- ================================================
create index idx_courses_title on courses(title);
create index idx_courses_rating on courses(rating);
create index idx_course_progress_user on course_progress(user_id, course_id);
create index idx_video_progress_user on video_progress(user_id, video_id);
create index idx_course_ratings_course on course_ratings(course_id);
create index idx_course_ratings_user on course_ratings(user_id);
create index idx_course_access_user on course_access(user_id, course_id);
create index idx_course_purchases_user on course_purchases(user_id, course_id);
create index idx_course_purchases_status on course_purchases(payment_status);

-- ================================================
-- 12. قيود إضافية
-- ================================================
alter table course_ratings add constraint rating_range check (rating between 1 and 5);
alter table course_videos add constraint positive_duration check (duration > 0);
alter table course_files add constraint positive_file_size check (file_size > 0);

-- جدول ربط الكورسات مع الأقسام والمراحل والفصول
create table course_department_semesters (  
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references courses(id) not null,
  department_id uuid references departments(id) not null,
  stage_id uuid references stages(id) not null,
  semester_id uuid references semesters(id) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(course_id, department_id, stage_id, semester_id)
);

-- تفعيل RLS
alter table course_department_semesters enable row level security;

-- سياسة القراءة للجميع
create policy "محتوى ربط الكورسات متاح للجميع"
  on course_department_semesters for select
  using (true);

-- سياسة التعديل للمسؤول
create policy "تعديل ربط الكورسات"
  on course_department_semesters for all
  using (is_admin());

-- إضافة index للأداء
create index idx_course_dept_stage_sem 
  on course_department_semesters(course_id, department_id, stage_id, semester_id);

-- INSERT INTO departments (name, code) VALUES
-- ('علوم الحاسوب', 'CS'),
-- ('نظم المعلومات', 'IS'),
-- ('الأنظمة الطبية', 'MS'),
-- ('الأمن السيبراني', 'CY');

-- INSERT INTO stages (name, level) VALUES
-- ('المرحلة الأولى', 1),
-- ('المرحلة الثانية', 2),
-- ('المرحلة الثالثة', 3),
-- ('المرحلة الرابعة', 4);

-- -- أولاً نحتاج للحصول على معرفات الأقسام والمراحل
-- WITH dept_cs AS (
--   SELECT id FROM departments WHERE code = 'CS'
-- ), dept_is AS (
--   SELECT id FROM departments WHERE code = 'IS'
-- ), dept_ms AS (
--   SELECT id FROM departments WHERE code = 'MS'
-- ), dept_cy AS (
--   SELECT id FROM departments WHERE code = 'CY'
-- ), stage_1 AS (
--   SELECT id FROM stages WHERE level = 1
-- ), stage_2 AS (
--   SELECT id FROM stages WHERE level = 2
-- ), stage_3 AS (
--   SELECT id FROM stages WHERE level = 3
-- ), stage_4 AS (
--   SELECT id FROM stages WHERE level = 4
-- )
-- -- إضافة الفصول لعلوم الحاسوب
-- INSERT INTO semesters (name, stage_id, department_id, semester_number)
-- SELECT 
--   CASE 
--     WHEN semester_number = 1 THEN 'الكورس الأول'
--     ELSE 'الكورس الثاني'
--   END,
--   s.id,
--   d.id,
--   semester_number
-- FROM 
--   (SELECT id FROM stages) s,
--   (SELECT id FROM departments WHERE code = 'CS') d,
--   (SELECT 1 AS semester_number UNION SELECT 2) sem;

-- -- إضافة الفصول لنظم المعلومات
-- INSERT INTO semesters (name, stage_id, department_id, semester_number)
-- SELECT 
--   CASE 
--     WHEN semester_number = 1 THEN 'الكورس الأول'
--     ELSE 'الكورس الثاني'
--   END,
--   s.id,
--   d.id,
--   semester_number
-- FROM 
--   (SELECT id FROM stages) s,
--   (SELECT id FROM departments WHERE code = 'IS') d,
--   (SELECT 1 AS semester_number UNION SELECT 2) sem;

-- -- إضافة الفصول للأنظمة الطبية
-- INSERT INTO semesters (name, stage_id, department_id, semester_number)
-- SELECT 
--   CASE 
--     WHEN semester_number = 1 THEN 'الكورس الأول'
--     ELSE 'الكورس الثاني'
--   END,
--   s.id,
--   d.id,
--   semester_number
-- FROM 
--   (SELECT id FROM stages) s,
--   (SELECT id FROM departments WHERE code = 'MS') d,
--   (SELECT 1 AS semester_number UNION SELECT 2) sem;

-- -- إضافة الفصول للأمن السيبراني
-- INSERT INTO semesters (name, stage_id, department_id, semester_number)
-- SELECT 
--   CASE 
--     WHEN semester_number = 1 THEN 'الكورس الأول'
--     ELSE 'الكورس الثاني'
--   END,
--   s.id,
--   d.id,
--   semester_number
-- FROM 
--   (SELECT id FROM stages) s,
--   (SELECT id FROM departments WHERE code = 'CY') d,
--   (SELECT 1 AS semester_number UNION SELECT 2) sem;


  -- التحقق من الأقسام
SELECT * FROM departments ORDER BY created_at;

-- التحقق من المراحل
SELECT * FROM stages ORDER BY level;

-- التحقق من الفصول
SELECT 
    s.name as semester_name,
    st.name as stage_name,
    d.name as department_name,
    s.semester_number
FROM semesters s
JOIN stages st ON s.stage_id = st.id
JOIN departments d ON s.department_id = d.id
ORDER BY d.name, st.level, s.semester_number;