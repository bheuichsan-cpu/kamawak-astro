-- =====================================================================
-- 01-profiles-fungsi.sql
-- Struktur baru: tabel profiles, trigger dari auth.users, fungsi bantu
-- peran, kolom baru di wisata/transaksi/tarik_saldo, tabel promo.
-- BELUM DIJALANKAN di database mana pun. Tanpa BEGIN/COMMIT (dibungkus
-- oleh pemanggil: lihat 99-dry-run.sql). Aman diulang (idempoten).
-- Skema asal: _skema-kolom.json (metadata produksi 13 Nov 2026).
-- Tidak mengubah RLS tabel lama (itu di 03). Tabel BARU langsung dikunci
-- di sini supaya tidak sempat terbuka lewat hak bawaan Supabase.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tabel profiles (pengganti public.users; id = auth.users.id)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  nama             text,
  username         text,
  email            text,
  wa               text,
  role             text not null default 'Wisatawan',
  status_langganan text,
  nama_usaha       text,
  legacy_user_id   uuid,          -- baris public.users asal (diisi saat pewarisan)
  created_at       timestamptz not null default timezone('utc'::text, now())
);

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('Admin', 'Owner', 'Mitra', 'Wisatawan', 'Agen'));

alter table public.profiles drop constraint if exists profiles_status_langganan_check;
alter table public.profiles add constraint profiles_status_langganan_check
  check (status_langganan is null or status_langganan in ('Aktif', 'Pending', 'Nonaktif', 'Kadaluarsa'));

create unique index if not exists profiles_username_uniq on public.profiles (lower(username)) where username is not null;
create unique index if not exists profiles_legacy_user_uniq on public.profiles (legacy_user_id) where legacy_user_id is not null;
create index if not exists profiles_email_idx on public.profiles (lower(email));

-- Kunci SEKARANG (tabel baru tidak boleh sempat terbuka lewat default privileges).
alter table public.profiles enable row level security;
revoke all on table public.profiles from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. Fungsi bantu normalisasi nomor WA (08xx -> 628xx, hanya digit)
-- ---------------------------------------------------------------------
create or replace function public.norm_wa(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when d = '' then null
    when left(d, 1) = '0' then '62' || substr(d, 2)
    else d
  end
  from (select regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g') as d) s
$$;

-- ---------------------------------------------------------------------
-- 3. Pewarisan data dari public.users lama (hanya setelah email TERVERIFIKASI)
--    Peran/status TIDAK pernah diambil dari data pendaftaran; hanya dari baris
--    legacy yang emailnya sama dan sudah dikonfirmasi lewat Supabase Auth.
--    PRASYARAT: "Confirm email" di Authentication > Providers > Email = ON.
-- ---------------------------------------------------------------------
create or replace function public.warisi_legacy(p_id uuid, p_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  l      record;
  v_role text;
begin
  if p_email is null or btrim(p_email) = '' then return; end if;
  if to_regclass('public.users') is null then return; end if;
  if exists (select 1 from public.profiles where id = p_id and legacy_user_id is not null) then return; end if;

  execute 'select id, nama, username, wa, role, status_langganan from public.users '
          'where lower(btrim(email)) = lower(btrim($1)) order by created_at limit 1'
    into l using p_email;
  if not found then return; end if;

  v_role := case
    when lower(btrim(coalesce(l.role, ''))) = 'admin' then 'Admin'
    when lower(btrim(coalesce(l.role, ''))) = 'owner' then 'Owner'
    when lower(btrim(coalesce(l.role, ''))) = 'mitra' then 'Mitra'
    else 'Wisatawan'
  end;

  begin
    update public.profiles
       set nama = coalesce(nullif(btrim(l.nama), ''), nama),
           username = coalesce(nullif(lower(btrim(l.username)), ''), username),
           wa = coalesce(nullif(btrim(l.wa), ''), wa),
           role = v_role,
           status_langganan = case
             when l.status_langganan in ('Aktif', 'Pending', 'Nonaktif', 'Kadaluarsa') then l.status_langganan
             else status_langganan end,
           legacy_user_id = l.id
     where id = p_id;
  exception when unique_violation then
    -- username/legacy bentrok: pewarisan tanpa username
    update public.profiles
       set nama = coalesce(nullif(btrim(l.nama), ''), nama),
           wa = coalesce(nullif(btrim(l.wa), ''), wa),
           role = v_role,
           status_langganan = case
             when l.status_langganan in ('Aktif', 'Pending', 'Nonaktif', 'Kadaluarsa') then l.status_langganan
             else status_langganan end
     where id = p_id;
  end;
end;
$$;

-- ---------------------------------------------------------------------
-- 4. Trigger: buat profil saat akun Auth dibuat; sinkron email; warisi legacy
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nama     text := nullif(btrim(left(coalesce(new.raw_user_meta_data ->> 'nama', ''), 120)), '');
  v_username text := nullif(lower(btrim(left(coalesce(new.raw_user_meta_data ->> 'username', ''), 40))), '');
  v_wa       text := nullif(btrim(left(coalesce(new.raw_user_meta_data ->> 'wa', ''), 30)), '');
begin
  v_nama := coalesce(v_nama, nullif(split_part(coalesce(new.email, ''), '@', 1), ''));
  begin
    insert into public.profiles (id, nama, username, email, wa, role)
    values (new.id, v_nama, v_username, new.email, v_wa, 'Wisatawan')   -- role SELALU Wisatawan
    on conflict (id) do nothing;
  exception when unique_violation then
    insert into public.profiles (id, nama, username, email, wa, role)
    values (new.id, v_nama, null, new.email, v_wa, 'Wisatawan')
    on conflict (id) do nothing;
  end;

  if new.email_confirmed_at is not null then
    perform public.warisi_legacy(new.id, new.email);
  end if;
  return new;
end;
$$;

create or replace function public.handle_user_updated()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is distinct from old.email then
    update public.profiles set email = new.email where id = new.id;
  end if;
  if old.email_confirmed_at is null and new.email_confirmed_at is not null then
    perform public.warisi_legacy(new.id, new.email);
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update of email, email_confirmed_at on auth.users
  for each row execute function public.handle_user_updated();

-- ---------------------------------------------------------------------
-- 5. Fungsi bantu peran (dipakai kebijakan RLS). SECURITY DEFINER agar tidak
--    rekursif terhadap RLS profiles.
-- ---------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select p.role = 'Admin' from public.profiles p where p.id = (select auth.uid())), false)
$$;

create or replace function public.is_mitra()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select p.role in ('Owner', 'Mitra') from public.profiles p where p.id = (select auth.uid())), false)
$$;

create or replace function public.is_agen()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select p.role = 'Agen' from public.profiles p where p.id = (select auth.uid())), false)
$$;

create or replace function public.is_owner_of(p_wisata_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_wisata_id is not null
     and (select public.is_mitra())
     and exists (select 1 from public.wisata w where w.id = p_wisata_id and w.owner_id = (select auth.uid()))
$$;

-- Hanya peran 'authenticated' yang boleh memanggil (dipakai di kebijakan).
revoke all on function public.norm_wa(text) from public, anon, authenticated;
revoke all on function public.warisi_legacy(uuid, text) from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.handle_user_updated() from public, anon, authenticated;
revoke all on function public.is_admin() from public, anon, authenticated;
revoke all on function public.is_mitra() from public, anon, authenticated;
revoke all on function public.is_agen() from public, anon, authenticated;
revoke all on function public.is_owner_of(uuid) from public, anon, authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_mitra() to authenticated;
grant execute on function public.is_agen() to authenticated;
grant execute on function public.is_owner_of(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Kolom baru pada tabel yang ada (tabel transaksi/leads/tarik_saldo
--    produksi saat ini KOSONG; wisata 9 baris; kolom lama tidak diubah)
-- ---------------------------------------------------------------------
-- wisata: pemilik sebagai uuid (teks 'owner' lama tetap dipertahankan)
alter table public.wisata add column if not exists owner_id uuid references public.profiles (id) on delete set null;
create index if not exists wisata_owner_id_idx on public.wisata (owner_id);

-- transaksi: skema produksi hanya (id, owner_nama, nominal, rekening, status, created_at),
-- sedangkan kode checkout/tiket memakai kolom pemesanan. Kolom pemesanan ditambah di sini.
-- Nama "namaProduk"/"totalBayar"/"rawVarian" sengaja camelCase karena kode situs sudah
-- membacanya dengan nama itu (profil/owner/admin); kolom baru lain memakai snake_case.
alter table public.transaksi add column if not exists wisata_id     uuid references public.wisata (id) on delete set null;
alter table public.transaksi add column if not exists user_id       uuid references public.profiles (id) on delete set null;
alter table public.transaksi add column if not exists nama_pemesan  text;
alter table public.transaksi add column if not exists "namaProduk"  text;
alter table public.transaksi add column if not exists tanggal       date;
alter table public.transaksi add column if not exists pax           integer;
alter table public.transaksi add column if not exists paket         text;
alter table public.transaksi add column if not exists "rawVarian"   text;
alter table public.transaksi add column if not exists "totalBayar"  numeric;
alter table public.transaksi add column if not exists diskon        numeric not null default 0;
alter table public.transaksi add column if not exists promo_kode    text;
alter table public.transaksi add column if not exists waktu_checkin timestamptz;
create index if not exists transaksi_user_id_idx   on public.transaksi (user_id);
create index if not exists transaksi_wisata_id_idx on public.transaksi (wisata_id);

-- tarik_saldo: pemilik sebagai uuid, diisi otomatis dari sesi login
alter table public.tarik_saldo add column if not exists owner_id uuid default auth.uid() references public.profiles (id) on delete set null;
create index if not exists tarik_saldo_owner_id_idx on public.tarik_saldo (owner_id);
alter table public.tarik_saldo drop constraint if exists tarik_saldo_nominal_positif;
alter table public.tarik_saldo add constraint tarik_saldo_nominal_positif check (nominal is null or nominal > 0) not valid;

create index if not exists leads_wisata_id_idx on public.leads (wisata_id);

-- ---------------------------------------------------------------------
-- 7. Isi wisata.owner_id otomatis dari teks 'owner' bila tepat satu profil
--    Owner/Mitra bernama sama (admin tidak perlu mengubah form CMS).
-- ---------------------------------------------------------------------
create or replace function public.wisata_isi_owner_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  arr uuid[];
begin
  if tg_op = 'UPDATE' and new.owner is distinct from old.owner and new.owner_id is not distinct from old.owner_id then
    new.owner_id := null;   -- pemilik (teks) diganti: petakan ulang
  end if;
  if new.owner_id is null and new.owner is not null and btrim(new.owner) <> '' then
    select array_agg(p.id) into arr
      from public.profiles p
     where lower(btrim(p.nama)) = lower(btrim(new.owner))
       and p.role in ('Owner', 'Mitra');
    if arr is not null and array_length(arr, 1) = 1 then
      new.owner_id := arr[1];
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.wisata_isi_owner_id() from public, anon, authenticated;

drop trigger if exists wisata_isi_owner_id on public.wisata;
create trigger wisata_isi_owner_id
  before insert or update of owner on public.wisata
  for each row execute function public.wisata_isi_owner_id();

-- Dijalankan SEKALI oleh admin database (SQL Editor, peran postgres) setelah
-- semua akun pemilik dibuat: select public.backfill_owner_id();
-- Mengembalikan jumlah wisata yang berhasil dipetakan; yang ambigu/tak cocok dibiarkan null.
create or replace function public.backfill_owner_id()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare n integer;
begin
  update public.wisata w
     set owner_id = x.pid
    from (
      select w2.id as wid, (array_agg(p.id))[1] as pid
        from public.wisata w2
        join public.profiles p
          on lower(btrim(p.nama)) = lower(btrim(w2.owner)) and p.role in ('Owner', 'Mitra')
       where w2.owner_id is null and w2.owner is not null and btrim(w2.owner) <> ''
       group by w2.id
      having count(*) = 1
    ) x
   where w.id = x.wid;
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.backfill_owner_id() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 8. Tabel promo (kupon divalidasi SERVER; sebelumnya hanya di localStorage
--    peramban sehingga bisa dipalsukan). Kosong sampai admin mengisinya.
-- ---------------------------------------------------------------------
create table if not exists public.promo (
  kode       text primary key,
  tipe       text not null default 'persen' check (tipe in ('persen', 'nominal')),
  nilai      numeric not null check (nilai > 0),
  minimal    numeric not null default 0 check (minimal >= 0),
  aktif      boolean not null default true,
  created_at timestamptz not null default timezone('utc'::text, now())
);
alter table public.promo enable row level security;
revoke all on table public.promo from public, anon, authenticated;
