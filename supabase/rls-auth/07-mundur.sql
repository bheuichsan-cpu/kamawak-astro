-- =====================================================================
-- 07-mundur.sql
-- Skrip mundur berpasangan dengan 03 (RLS) dan 04 (hak akses).
-- BAGIAN A: mengembalikan AKSES ke keadaan sebelum 03/04 (RLS mati, hak
--           anon/authenticated kembali). Data TIDAK berubah. WASPADA: ini
--           membuka kembali risiko lama; hanya untuk jeda singkat dan harus
--           BERPASANGAN dengan rollback deploy kode situs (Cloudflare Pages
--           -> Rollback ke deployment sebelumnya). Jangan salah satu saja.
-- BAGIAN B: (DIKOMENTARI) menghapus objek baru (profiles, RPC, kolom baru).
--           Hanya bila rencana dibatalkan total; MENGHAPUS DATA profiles,
--           transaksi baru, dan wisata_draf. Buka komentar dengan sengaja.
-- Hak yang dipulihkan = keadaan setelah Fase 1 (TRUNCATE/TRIGGER/REFERENCES
-- sengaja TIDAK dikembalikan). Uji skrip ini di proyek uji sebelum cutover.
-- BELUM DIJALANKAN. Tanpa BEGIN/COMMIT.
-- =====================================================================

-- ---------------------------------------------------------------------
-- BAGIAN A1. Matikan RLS pada tabel lama (kebalikan 03 bagian I)
-- ---------------------------------------------------------------------
alter table public.wisata      disable row level security;
alter table public.users       disable row level security;
alter table public.transaksi   disable row level security;
alter table public.buku_kas    disable row level security;
alter table public.tarik_saldo disable row level security;
alter table public.leads       disable row level security;

-- Tabel baru: biarkan RLS NYALA dan tertutup (tidak dipakai kode lama, dan
-- profiles berisi email/WA).  Tidak diubah di sini.

-- ---------------------------------------------------------------------
-- BAGIAN A2. Hapus kebijakan baru; pulihkan dua kebijakan lama (inert saat RLS mati)
-- ---------------------------------------------------------------------
drop policy if exists wisata_baca_publik     on public.wisata;
drop policy if exists wisata_baca_pemilik    on public.wisata;
drop policy if exists wisata_admin_semua     on public.wisata;
drop policy if exists transaksi_baca         on public.transaksi;
drop policy if exists buku_kas_admin         on public.buku_kas;
drop policy if exists tarik_saldo_insert     on public.tarik_saldo;
drop policy if exists tarik_saldo_baca       on public.tarik_saldo;
drop policy if exists tarik_saldo_ubah_admin on public.tarik_saldo;
drop policy if exists leads_insert_publik    on public.leads;
drop policy if exists leads_baca             on public.leads;

drop policy if exists "Public Read Wisata"  on public.wisata;
drop policy if exists "Public Insert Leads" on public.leads;
create policy "Public Read Wisata"  on public.wisata for select to public using (true);
create policy "Public Insert Leads" on public.leads  for insert to public with check (true);

-- ---------------------------------------------------------------------
-- BAGIAN A3. Kembalikan hak tabel (kebalikan 04): anon & authenticated
-- kembali boleh select/insert/update/delete pada 6 tabel lama.
-- ---------------------------------------------------------------------
grant select, insert, update, delete on public.wisata, public.users, public.transaksi,
                                         public.buku_kas, public.tarik_saldo, public.leads
  to anon, authenticated;

-- Default privileges: 04 mencabutnya. Keadaan sebelum 04 tidak tercatat di metadata
-- backup (mungkin sudah dicabut di Fase 1). Bila perlu pulihkan manual:
-- alter default privileges in schema public grant select, insert, update, delete on tables to anon, authenticated;

-- ---------------------------------------------------------------------
-- BAGIAN B (DIKOMENTARI). Buang objek baru. Buka komentar hanya bila
-- rencana dibatalkan total. Urutan: trigger -> fungsi -> tabel -> kolom.
-- ---------------------------------------------------------------------
-- drop trigger if exists on_auth_user_created on auth.users;
-- drop trigger if exists on_auth_user_updated on auth.users;
-- drop trigger if exists wisata_isi_owner_id on public.wisata;
--
-- drop function if exists public.ajukan_draf(text, text, text, text, numeric, text, text, text[], text, text, boolean);
-- drop function if exists public.setujui_draf(uuid, text);
-- drop function if exists public.cari_email(text);
-- drop function if exists public.username_tersedia(text);
-- drop function if exists public.catat_lead(uuid, text);
-- drop function if exists public.buat_transaksi(uuid, date, integer, text, text, text);
-- drop function if exists public.checkin_tiket(text);
-- drop function if exists public.ajukan_mitra(text, text);
-- drop function if exists public.admin_set_role(text, text);
-- drop function if exists public.admin_set_langganan(uuid, text);
-- drop function if exists public.admin_set_status_transaksi(uuid, text);
-- drop function if exists public.admin_set_owner_wisata(uuid, text);
-- drop function if exists public.backfill_owner_id();
-- drop function if exists public.wisata_isi_owner_id();
-- drop function if exists public.handle_user_updated();
-- drop function if exists public.handle_new_user();
-- drop function if exists public.warisi_legacy(uuid, text);
-- drop function if exists public.is_owner_of(uuid);
-- drop function if exists public.is_agen();
-- drop function if exists public.is_mitra();
-- drop function if exists public.is_admin();
-- drop function if exists public.norm_wa(text);
--
-- drop table if exists public.wisata_draf;
-- drop table if exists public.promo;
--
-- alter table public.tarik_saldo drop column if exists owner_id;
-- alter table public.tarik_saldo drop constraint if exists tarik_saldo_nominal_positif;
-- alter table public.wisata drop column if exists owner_id;
-- alter table public.transaksi
--   drop column if exists wisata_id, drop column if exists user_id, drop column if exists nama_pemesan,
--   drop column if exists "namaProduk", drop column if exists tanggal, drop column if exists pax,
--   drop column if exists paket, drop column if exists "rawVarian", drop column if exists "totalBayar",
--   drop column if exists diskon, drop column if exists promo_kode, drop column if exists waktu_checkin;
-- drop table if exists public.profiles;   -- terakhir (dirujuk kolom di atas)
