-- =====================================================================
-- 03-kebijakan-rls.sql
-- Kebijakan RLS per tabel. URUTAN: hapus kebijakan lama -> buat kebijakan
-- baru -> NYALAKAN RLS (paling akhir). Butuh 01 dan 02.
-- Semua kebijakan memakai "to <peran>" eksplisit (tidak ada "to public").
-- BELUM DIJALANKAN. Tanpa BEGIN/COMMIT.
-- PERINGATAN: begitu file ini dijalankan di produksi, kode situs LAMA
-- (login teks biasa, users) berhenti bekerja: ini bagian cutover (jeda).
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. Hapus kebijakan lama (aman bila sudah tidak ada)
-- ---------------------------------------------------------------------
drop policy if exists "Public Read Wisata"   on public.wisata;
drop policy if exists "Public Insert Leads"  on public.leads;
-- bila file ini diulang: hapus juga versi baru supaya create policy tidak bentrok
drop policy if exists wisata_baca_publik        on public.wisata;
drop policy if exists wisata_baca_pemilik       on public.wisata;
drop policy if exists wisata_admin_semua        on public.wisata;
drop policy if exists profiles_baca_sendiri     on public.profiles;
drop policy if exists profiles_ubah_sendiri     on public.profiles;
drop policy if exists transaksi_baca            on public.transaksi;
drop policy if exists buku_kas_admin            on public.buku_kas;
drop policy if exists tarik_saldo_insert        on public.tarik_saldo;
drop policy if exists tarik_saldo_baca          on public.tarik_saldo;
drop policy if exists tarik_saldo_ubah_admin    on public.tarik_saldo;
drop policy if exists leads_insert_publik       on public.leads;
drop policy if exists leads_baca                on public.leads;
drop policy if exists promo_admin               on public.promo;

-- ---------------------------------------------------------------------
-- B. wisata: publik hanya baris Aktif; pemilik melihat miliknya; admin semua
--    (pemilik TIDAK menulis wisata lewat kode saat ini)
-- ---------------------------------------------------------------------
create policy wisata_baca_publik on public.wisata
  for select to anon, authenticated
  using (status = 'Aktif');

create policy wisata_baca_pemilik on public.wisata
  for select to authenticated
  using (owner_id = (select auth.uid()));

create policy wisata_admin_semua on public.wisata
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ---------------------------------------------------------------------
-- C. profiles (pengganti users): baca/ubah baris sendiri; admin baca semua.
--    Ubah peran/status hanya lewat RPC admin (hak kolom di 04: authenticated
--    hanya boleh UPDATE kolom nama, username, wa).
-- ---------------------------------------------------------------------
create policy profiles_baca_sendiri on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

create policy profiles_ubah_sendiri on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- D. transaksi: BACA saja. Tulis hanya lewat RPC buat_transaksi / checkin_tiket
--    / admin_set_status_transaksi (tidak ada kebijakan insert/update/delete).
-- ---------------------------------------------------------------------
create policy transaksi_baca on public.transaksi
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_owner_of(wisata_id))
    or (select public.is_admin())
  );

-- ---------------------------------------------------------------------
-- E. buku_kas: admin saja
-- ---------------------------------------------------------------------
create policy buku_kas_admin on public.buku_kas
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ---------------------------------------------------------------------
-- F. tarik_saldo: owner buat/lihat miliknya; admin baca & ubah status.
--    Catatan: batas nominal terhadap saldo TIDAK diperiksa di database
--    (saldo dihitung di klien dari transaksi); admin yang menyetujui.
-- ---------------------------------------------------------------------
create policy tarik_saldo_insert on public.tarik_saldo
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and status = 'Pending' and (select public.is_mitra()));

create policy tarik_saldo_baca on public.tarik_saldo
  for select to authenticated
  using (owner_id = (select auth.uid()) or (select public.is_admin()));

create policy tarik_saldo_ubah_admin on public.tarik_saldo
  for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ---------------------------------------------------------------------
-- G. leads: insert publik diperketat (platform dibatasi, wisata harus Aktif);
--    baca hanya pemilik wisata itu atau admin. Platform diasumsikan
--    'wa','ig','fb','tiktok' (belum ada kode yang menulis leads).
-- ---------------------------------------------------------------------
create policy leads_insert_publik on public.leads
  for insert to anon, authenticated
  with check (
    platform in ('wa', 'ig', 'fb', 'tiktok')
    and wisata_id is not null
    and exists (select 1 from public.wisata w where w.id = wisata_id and w.status = 'Aktif')
  );

create policy leads_baca on public.leads
  for select to authenticated
  using ((select public.is_owner_of(wisata_id)) or (select public.is_admin()));

-- ---------------------------------------------------------------------
-- H. promo: admin saja (RPC buat_transaksi membaca lewat SECURITY DEFINER)
-- ---------------------------------------------------------------------
create policy promo_admin on public.promo
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ---------------------------------------------------------------------
-- I. NYALAKAN RLS (TERAKHIR). public.users lama: RLS nyala TANPA kebijakan
--    = tertutup total untuk anon/authenticated (hanya peran postgres/service_role).
-- ---------------------------------------------------------------------
alter table public.wisata      enable row level security;
alter table public.profiles    enable row level security;
alter table public.transaksi   enable row level security;
alter table public.buku_kas    enable row level security;
alter table public.tarik_saldo enable row level security;
alter table public.leads       enable row level security;
alter table public.promo       enable row level security;
alter table public.users       enable row level security;
