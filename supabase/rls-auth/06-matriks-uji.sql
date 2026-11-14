-- =====================================================================
-- 06-matriks-uji.sql
-- Matriks uji akses sebagai anon / wisatawan / owner / admin / agen.
-- Dijalankan SETELAH 01-05 diterapkan (di proyek UJI, atau produksi bila
-- ragu: seluruh isi dibungkus begin ... rollback sehingga semua fixture dan
-- hasil uji dibatalkan; JANGAN ganti rollback menjadi commit).
-- Cara pakai: tempel semua, jalankan; hasil ada di tabel hasil paling bawah.
-- Kolom 'lulus' harus TRUE di semua baris. Satu baris FALSE = berhenti.
-- Pembacaan hasil: ditolak = error hak/RLS (42501), kosong = 0 baris,
-- berhasil:N = N baris, galat:KODE = error lain (22023 parameter, P0002
-- tidak tersedia, 54000 batas). Pola harapan memakai LIKE.
-- BELUM DIJALANKAN. Asumsi belum diverifikasi: kolom wajib tabel auth.users
-- di versi Supabase yang dipakai (fixture di bawah mungkin perlu disesuaikan).
-- =====================================================================
begin;

-- ---------- pembantu uji (schema sementara, ikut dibatalkan) ----------
create schema uji;
grant usage on schema uji to public;
create table uji.hasil (n serial primary key, nama text, harapan text, aktual text, lulus boolean);
grant all on uji.hasil to public;
grant usage on sequence uji.hasil_n_seq to public;
create function uji.coba(p_nama text, p_sql text, p_harapan text) returns void
language plpgsql as $f$
declare n bigint; a text;
begin
  begin
    execute p_sql;
    get diagnostics n = row_count;
    a := case when n = 0 then 'kosong' else 'berhasil:' || n end;
  exception
    when insufficient_privilege then a := 'ditolak';
    when others then a := 'galat:' || sqlstate;
  end;
  insert into uji.hasil (nama, harapan, aktual, lulus) values (p_nama, p_harapan, a, a like p_harapan);
end $f$;
grant execute on function uji.coba(text, text, text) to public;

-- ---------- fixture (sebagai postgres) ----------

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'uji-admin@example.test', now(),
        '{"provider":"email"}', '{"nama":"UJI Admin","username":"uji-admin"}', now(), now());

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'uji-owner1@example.test', now(),
        '{"provider":"email"}', '{"nama":"UJI Owner Satu","username":"uji-owner1"}', now(), now());

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'uji-owner2@example.test', now(),
        '{"provider":"email"}', '{"nama":"UJI Owner Dua","username":"uji-owner2"}', now(), now());

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'uji-wisatawan1@example.test', now(),
        '{"provider":"email"}', '{"nama":"UJI Wisatawan Satu","username":"uji-wisatawan1"}', now(), now());

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'uji-wisatawan2@example.test', now(),
        '{"provider":"email"}', '{"nama":"UJI Wisatawan Dua","username":"uji-wisatawan2"}', now(), now());

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'uji-agen@example.test', now(),
        '{"provider":"email"}', '{"nama":"UJI Agen","username":"uji-agen"}', now(), now());


update public.profiles set role = 'Admin'  where id = '00000000-0000-4000-8000-0000000000a1';
update public.profiles set role = 'Owner', status_langganan = 'Aktif' where id in ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000b2');
update public.profiles set role = 'Agen'   where id = '00000000-0000-4000-8000-0000000000d1';

insert into public.wisata (id, nama, harga, status, owner, owner_id, varian) values
 ('00000000-0000-4000-8000-0000000000e1', 'UJI Wisata Satu', 100000, 'Aktif',    'UJI Owner Satu', '00000000-0000-4000-8000-0000000000b1', 'Reguler:0,Premium:50000'),
 ('00000000-0000-4000-8000-0000000000e3', 'UJI Wisata Nonaktif', 100000, 'Nonaktif', 'UJI Owner Satu', '00000000-0000-4000-8000-0000000000b1', null);
-- pemilik hanya lewat teks: owner_id harus terisi otomatis oleh trigger
insert into public.wisata (id, nama, harga, status, owner) values
 ('00000000-0000-4000-8000-0000000000e2', 'UJI Wisata Dua', 100000, 'Aktif', 'UJI Owner Dua');

insert into public.transaksi (id, owner_nama, nominal, status, wisata_id, user_id, nama_pemesan, "namaProduk", tanggal, pax, paket, "totalBayar") values
 ('00000000-0000-4000-8000-0000000000f1', 'UJI Owner Satu', 100000, 'Berhasil', '00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1', 'UJI Wisatawan Satu', 'UJI Wisata Satu', current_date + 7, 1, 'reguler', 100000),
 ('00000000-0000-4000-8000-0000000000f2', 'UJI Owner Dua',  100000, 'Berhasil', '00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000c2', 'UJI Wisatawan Dua',  'UJI Wisata Dua',  current_date + 7, 1, 'reguler', 100000),
 ('00000000-0000-4000-8000-0000000000f3', 'UJI Owner Satu', 100000, 'Pending',  '00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1', 'UJI Wisatawan Satu', 'UJI Wisata Satu', current_date + 7, 1, 'reguler', 100000),
 ('00000000-0000-4000-8000-0000000000f4', 'UJI Owner Satu', 100000, 'Berhasil', '00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1', 'UJI Wisatawan Satu', 'UJI Wisata Satu', current_date + 7, 1, 'reguler', 100000);

insert into public.leads (wisata_id, platform) values ('00000000-0000-4000-8000-0000000000e1', 'wa'), ('00000000-0000-4000-8000-0000000000e2', 'wa');
insert into public.promo (kode, tipe, nilai, minimal, aktif) values ('UJI10', 'persen', 10, 0, true);

-- pewarisan legacy: peran TIDAK boleh naik sebelum email terkonfirmasi
insert into public.users (nama, password, role, email) values ('UJI Legacy', 'x', 'Admin', 'uji-legacy@example.test');

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000a9', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'uji-legacy@example.test', null,
        '{"provider":"email"}', '{"nama":"UJI Legacy Baru","username":"uji-legacy"}', now(), now());


-- ===== 0. Fixture & trigger (sebagai postgres) =====
reset role;
select uji.coba('0.1 profil dibuat otomatis, peran Wisatawan', $q$select 1 from public.profiles where id = '00000000-0000-4000-8000-0000000000c1' and role = 'Wisatawan' and email = 'uji-wisatawan1@example.test'$q$, 'berhasil:1');
select uji.coba('0.2 wisata.owner_id terisi dari teks owner', $q$select 1 from public.wisata where id = '00000000-0000-4000-8000-0000000000e2' and owner_id = '00000000-0000-4000-8000-0000000000b2'$q$, 'berhasil:1');
select uji.coba('0.3 legacy BELUM dikonfirmasi: peran tetap Wisatawan', $q$select 1 from public.profiles where id = '00000000-0000-4000-8000-0000000000a9' and role = 'Wisatawan'$q$, 'berhasil:1');
select uji.coba('0.4 konfirmasi email -> mewarisi peran legacy', $q$update auth.users set email_confirmed_at = now() where id = '00000000-0000-4000-8000-0000000000a9'$q$, 'berhasil:1');
select uji.coba('0.5 legacy sesudah konfirmasi: peran Admin', $q$select 1 from public.profiles where id = '00000000-0000-4000-8000-0000000000a9' and role = 'Admin'$q$, 'berhasil:1');

-- ===== 1. ANON =====
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true), set_config('request.jwt.claim.sub', '', true);
set local role anon;

select uji.coba('1.01 anon baca wisata Aktif', $q$select 1 from public.wisata where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'berhasil:1');
select uji.coba('1.02 anon TIDAK melihat wisata Nonaktif', $q$select 1 from public.wisata where id = '00000000-0000-4000-8000-0000000000e3'$q$, 'kosong');
select uji.coba('1.03 anon select users', $q$select 1 from public.users$q$, 'ditolak');
select uji.coba('1.03 anon select profiles', $q$select 1 from public.profiles$q$, 'ditolak');
select uji.coba('1.03 anon select transaksi', $q$select 1 from public.transaksi$q$, 'ditolak');
select uji.coba('1.03 anon select buku_kas', $q$select 1 from public.buku_kas$q$, 'ditolak');
select uji.coba('1.03 anon select tarik_saldo', $q$select 1 from public.tarik_saldo$q$, 'ditolak');
select uji.coba('1.03 anon select leads', $q$select 1 from public.leads$q$, 'ditolak');
select uji.coba('1.03 anon select promo', $q$select 1 from public.promo$q$, 'ditolak');
select uji.coba('1.03 anon select wisata_draf', $q$select 1 from public.wisata_draf$q$, 'ditolak');
select uji.coba('1.04 anon insert wisata', $q$insert into public.wisata (nama) values ('x')$q$, 'ditolak');
select uji.coba('1.05 anon update wisata', $q$update public.wisata set nama = 'x' where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'ditolak');
select uji.coba('1.06 anon delete wisata', $q$delete from public.wisata where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'ditolak');
select uji.coba('1.07 anon insert transaksi', $q$insert into public.transaksi (owner_nama, nominal) values ('x', 1)$q$, 'ditolak');
select uji.coba('1.08 anon update transaksi', $q$update public.transaksi set status = 'Berhasil'$q$, 'ditolak');
select uji.coba('1.09 anon delete buku_kas', $q$delete from public.buku_kas$q$, 'ditolak');
select uji.coba('1.10 anon insert tarik_saldo', $q$insert into public.tarik_saldo (owner, nominal, status) values ('x', 1, 'Pending')$q$, 'ditolak');
select uji.coba('1.11 anon update users lama', $q$update public.users set role = 'Admin'$q$, 'ditolak');
select uji.coba('1.12 anon truncate transaksi', $q$truncate public.transaksi$q$, 'ditolak');
select uji.coba('1.13 anon insert leads valid', $q$insert into public.leads (wisata_id, platform) values ('00000000-0000-4000-8000-0000000000e1', 'wa')$q$, 'berhasil:1');
select uji.coba('1.14 anon insert leads platform salah', $q$insert into public.leads (wisata_id, platform) values ('00000000-0000-4000-8000-0000000000e1', 'spam')$q$, 'ditolak');
select uji.coba('1.15 anon insert leads wisata Nonaktif', $q$insert into public.leads (wisata_id, platform) values ('00000000-0000-4000-8000-0000000000e3', 'wa')$q$, 'ditolak');
select uji.coba('1.16 anon select leads', $q$select 1 from public.leads$q$, 'ditolak');
select uji.coba('1.17 anon RPC buat_transaksi', $q$select public.buat_transaksi('00000000-0000-4000-8000-0000000000e1', current_date + 3, 1)$q$, 'ditolak');
select uji.coba('1.18 anon RPC checkin_tiket', $q$select public.checkin_tiket('00000000-0000-4000-8000-0000000000f1')$q$, 'ditolak');
select uji.coba('1.19 anon RPC admin_set_role', $q$select public.admin_set_role('uji-wisatawan1@example.test', 'Admin')$q$, 'ditolak');
select uji.coba('1.20 anon RPC ajukan_draf', $q$select public.ajukan_draf('Nama Uji', null, null, null, null, null, null, null, 'sumber', 'izin')$q$, 'ditolak');
select uji.coba('1.21 anon RPC cari_email (boleh)', $q$select public.cari_email('uji-wisatawan1')$q$, 'berhasil:1');
select uji.coba('1.22 anon RPC username_tersedia (boleh)', $q$select public.username_tersedia('uji-wisatawan1')$q$, 'berhasil:1');
select uji.coba('1.23 anon RPC catat_lead (boleh)', $q$select public.catat_lead('00000000-0000-4000-8000-0000000000e1', 'ig')$q$, 'berhasil:1');
select uji.coba('1.24 anon fungsi bantu is_admin tidak bisa dipanggil', $q$select public.is_admin()$q$, 'ditolak');

-- ===== 2. WISATAWAN W1 =====
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true), set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000c1', true);
set local role authenticated;

select uji.coba('2.01 W1 hanya melihat profil sendiri', $q$select 1 from public.profiles$q$, 'berhasil:1');
select uji.coba('2.02 W1 tidak melihat profil W2', $q$select 1 from public.profiles where id = '00000000-0000-4000-8000-0000000000c2'$q$, 'kosong');
select uji.coba('2.03 W1 naikkan role sendiri', $q$update public.profiles set role = 'Admin' where id = '00000000-0000-4000-8000-0000000000c1'$q$, 'ditolak');
select uji.coba('2.04 W1 ubah status_langganan sendiri', $q$update public.profiles set status_langganan = 'Aktif' where id = '00000000-0000-4000-8000-0000000000c1'$q$, 'ditolak');
select uji.coba('2.05 W1 ubah nama sendiri (boleh)', $q$update public.profiles set nama = 'UJI Wisatawan Satu' where id = '00000000-0000-4000-8000-0000000000c1'$q$, 'berhasil:1');
select uji.coba('2.06 W1 ubah nama W2', $q$update public.profiles set nama = 'x' where id = '00000000-0000-4000-8000-0000000000c2'$q$, 'kosong');
select uji.coba('2.07 W1 baca transaksi sendiri (T1,T3,T4)', $q$select 1 from public.transaksi$q$, 'berhasil:3');
select uji.coba('2.08 W1 tidak melihat transaksi W2', $q$select 1 from public.transaksi where id = '00000000-0000-4000-8000-0000000000f2'$q$, 'kosong');
select uji.coba('2.09 W1 insert transaksi langsung', $q$insert into public.transaksi (owner_nama, nominal, user_id) values ('x', 1, '00000000-0000-4000-8000-0000000000c1')$q$, 'ditolak');
select uji.coba('2.10 W1 update transaksi langsung', $q$update public.transaksi set status = 'Berhasil' where id = '00000000-0000-4000-8000-0000000000f3'$q$, 'ditolak');
select uji.coba('2.11 W1 delete transaksi langsung', $q$delete from public.transaksi where id = '00000000-0000-4000-8000-0000000000f3'$q$, 'ditolak');
select uji.coba('2.12 W1 buat_transaksi valid (varian Premium, harga server 150000)', $q$select public.buat_transaksi('00000000-0000-4000-8000-0000000000e1', current_date + 5, 1, 'reguler', 'Premium:50000', '')$q$, 'berhasil:1');
select uji.coba('2.13 W1 total dihitung server', $q$select 1 from public.transaksi where user_id = '00000000-0000-4000-8000-0000000000c1' and "totalBayar" = 150000 and status = 'Pending'$q$, 'berhasil:1');
select uji.coba('2.14 W1 buat_transaksi dengan kupon UJI10, pax 2 => 180000', $q$select public.buat_transaksi('00000000-0000-4000-8000-0000000000e1', current_date + 5, 2, 'reguler', '', 'UJI10')$q$, 'berhasil:1');
select uji.coba('2.15 W1 total kupon benar', $q$select 1 from public.transaksi where user_id = '00000000-0000-4000-8000-0000000000c1' and "totalBayar" = 180000 and promo_kode = 'UJI10'$q$, 'berhasil:1');
select uji.coba('2.16 W1 buat_transaksi pax 0', $q$select public.buat_transaksi('00000000-0000-4000-8000-0000000000e1', current_date + 5, 0)$q$, 'galat:22023');
select uji.coba('2.17 W1 buat_transaksi tanggal lampau', $q$select public.buat_transaksi('00000000-0000-4000-8000-0000000000e1', current_date - 3, 1)$q$, 'galat:22023');
select uji.coba('2.18 W1 buat_transaksi wisata Nonaktif', $q$select public.buat_transaksi('00000000-0000-4000-8000-0000000000e3', current_date + 5, 1)$q$, 'galat:P0002');
select uji.coba('2.19 W1 buat_transaksi varian palsu', $q$select public.buat_transaksi('00000000-0000-4000-8000-0000000000e1', current_date + 5, 1, 'reguler', 'Gratis:0', '')$q$, 'galat:22023');
select uji.coba('2.20 W1 buat_transaksi kupon palsu', $q$select public.buat_transaksi('00000000-0000-4000-8000-0000000000e1', current_date + 5, 1, 'reguler', '', 'PALSU99')$q$, 'galat:22023');
select uji.coba('2.21 W1 checkin_tiket tiket sendiri -> bukan pemilik', $q$select 1 where (public.checkin_tiket('00000000-0000-4000-8000-0000000000f1') ->> 'hasil') = 'tidak_ditemukan'$q$, 'berhasil:1');
select uji.coba('2.22 W1 baca buku_kas', $q$select 1 from public.buku_kas$q$, 'kosong');
select uji.coba('2.23 W1 insert buku_kas', $q$insert into public.buku_kas (jenis, kategori, nominal) values ('Pemasukan', 'x', 1)$q$, 'ditolak');
select uji.coba('2.24 W1 insert tarik_saldo (bukan mitra)', $q$insert into public.tarik_saldo (owner, nominal, status, owner_id) values ('x', 1000, 'Pending', '00000000-0000-4000-8000-0000000000c1')$q$, 'ditolak');
select uji.coba('2.25 W1 baca leads', $q$select 1 from public.leads$q$, 'kosong');
select uji.coba('2.26 W1 baca wisata Nonaktif', $q$select 1 from public.wisata where id = '00000000-0000-4000-8000-0000000000e3'$q$, 'kosong');
select uji.coba('2.27 W1 insert wisata', $q$insert into public.wisata (nama) values ('x')$q$, 'ditolak');
select uji.coba('2.28 W1 update wisata', $q$update public.wisata set nama = 'x' where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'kosong');
select uji.coba('2.29 W1 delete wisata', $q$delete from public.wisata where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'kosong');
select uji.coba('2.30 W1 baca users lama', $q$select 1 from public.users$q$, 'ditolak');
select uji.coba('2.31 W1 baca promo', $q$select 1 from public.promo$q$, 'kosong');
select uji.coba('2.32 W1 admin_set_role', $q$select public.admin_set_role('uji-wisatawan1@example.test', 'Admin')$q$, 'ditolak');
select uji.coba('2.33 W1 admin_set_langganan', $q$select public.admin_set_langganan('00000000-0000-4000-8000-0000000000c1', 'Aktif')$q$, 'ditolak');
select uji.coba('2.34 W1 admin_set_status_transaksi', $q$select public.admin_set_status_transaksi('00000000-0000-4000-8000-0000000000f3', 'Berhasil')$q$, 'ditolak');
select uji.coba('2.35 W1 ajukan_draf (bukan agen)', $q$select public.ajukan_draf('Nama Uji', null, null, null, null, null, null, null, 'sumber', 'izin')$q$, 'ditolak');
select uji.coba('2.36 W1 setujui_draf', $q$select public.setujui_draf('00000000-0000-4000-8000-0000000000c1')$q$, 'ditolak');
select uji.coba('2.37 W1 baca wisata_draf', $q$select 1 from public.wisata_draf$q$, 'kosong');
select uji.coba('2.38 W1 ajukan_mitra (boleh, peran tidak berubah)', $q$select public.ajukan_mitra('081200000000', 'Usaha Uji')$q$, 'berhasil:1');
select uji.coba('2.39 W1 sesudah ajukan_mitra peran tetap Wisatawan', $q$select 1 from public.profiles where id = '00000000-0000-4000-8000-0000000000c1' and role = 'Wisatawan' and status_langganan = 'Pending'$q$, 'berhasil:1');

-- ===== 3. OWNER O1 =====
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}', true), set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000b1', true);
set local role authenticated;

select uji.coba('3.01 O1 baca transaksi wisatanya (T1,T3,T4 + milik baru W1 dari uji 2)', $q$select 1 from public.transaksi where id in ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000f3', '00000000-0000-4000-8000-0000000000f4')$q$, 'berhasil:3');
select uji.coba('3.02 O1 tidak melihat transaksi wisata O2', $q$select 1 from public.transaksi where id = '00000000-0000-4000-8000-0000000000f2'$q$, 'kosong');
select uji.coba('3.03 O1 check-in tiket Berhasil milik wisatanya -> ok', $q$select 1 where (public.checkin_tiket('00000000-0000-4000-8000-0000000000f1') ->> 'hasil') = 'ok'$q$, 'berhasil:1');
select uji.coba('3.04 O1 check-in ulang -> sudah_digunakan', $q$select 1 where (public.checkin_tiket('00000000-0000-4000-8000-0000000000f1') ->> 'hasil') = 'sudah_digunakan'$q$, 'berhasil:1');
select uji.coba('3.05 O1 check-in tiket Pending -> belum_dibayar', $q$select 1 where (public.checkin_tiket('00000000-0000-4000-8000-0000000000f3') ->> 'hasil') = 'belum_dibayar'$q$, 'berhasil:1');
select uji.coba('3.06 O1 check-in tiket wisata O2 -> tidak_ditemukan', $q$select 1 where (public.checkin_tiket('00000000-0000-4000-8000-0000000000f2') ->> 'hasil') = 'tidak_ditemukan'$q$, 'berhasil:1');
select uji.coba('3.07 O1 check-in kode bukan uuid -> tidak_ditemukan', $q$select 1 where (public.checkin_tiket('TRX-123') ->> 'hasil') = 'tidak_ditemukan'$q$, 'berhasil:1');
select uji.coba('3.08 O1 update transaksi langsung', $q$update public.transaksi set status = 'Berhasil' where id = '00000000-0000-4000-8000-0000000000f3'$q$, 'ditolak');
select uji.coba('3.09 O1 baca wisata Nonaktif miliknya', $q$select 1 from public.wisata where id = '00000000-0000-4000-8000-0000000000e3'$q$, 'berhasil:1');
select uji.coba('3.10 O1 tidak melihat wisata Nonaktif orang lain (tidak ada) / update wisata sendiri ditolak RLS', $q$update public.wisata set nama = 'x' where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'kosong');
select uji.coba('3.11 O1 insert wisata', $q$insert into public.wisata (nama) values ('x')$q$, 'ditolak');
select uji.coba('3.12 O1 delete wisata', $q$delete from public.wisata where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'kosong');
select uji.coba('3.13 O1 baca leads wisatanya', $q$select 1 from public.leads where wisata_id = '00000000-0000-4000-8000-0000000000e1'$q$, 'berhasil:%');
select uji.coba('3.14 O1 tidak melihat leads wisata O2', $q$select 1 from public.leads where wisata_id = '00000000-0000-4000-8000-0000000000e2'$q$, 'kosong');
select uji.coba('3.15 O1 insert tarik_saldo sendiri', $q$insert into public.tarik_saldo (owner, nominal, rekening, status) values ('UJI Owner Satu', 50000, 'rek-uji', 'Pending')$q$, 'berhasil:1');
select uji.coba('3.16 O1 tarik_saldo status bukan Pending', $q$insert into public.tarik_saldo (owner, nominal, status) values ('x', 1000, 'Selesai')$q$, 'ditolak');
select uji.coba('3.17 O1 tarik_saldo atas nama owner lain', $q$insert into public.tarik_saldo (owner, nominal, status, owner_id) values ('x', 1000, 'Pending', '00000000-0000-4000-8000-0000000000b2')$q$, 'ditolak');
select uji.coba('3.18 O1 tarik_saldo nominal negatif', $q$insert into public.tarik_saldo (owner, nominal, status) values ('x', -5, 'Pending')$q$, 'galat:23514');
select uji.coba('3.19 O1 baca tarik_saldo sendiri saja', $q$select 1 from public.tarik_saldo$q$, 'berhasil:1');
select uji.coba('3.20 O1 ubah status tarik_saldo', $q$update public.tarik_saldo set status = 'Selesai'$q$, 'kosong');
select uji.coba('3.21 O1 baca buku_kas', $q$select 1 from public.buku_kas$q$, 'kosong');
select uji.coba('3.22 O1 naikkan role sendiri', $q$update public.profiles set role = 'Admin' where id = '00000000-0000-4000-8000-0000000000b1'$q$, 'ditolak');
select uji.coba('3.23 O1 admin_set_owner_wisata', $q$select public.admin_set_owner_wisata('00000000-0000-4000-8000-0000000000e1', 'uji-owner1@example.test')$q$, 'ditolak');

-- ===== 4. ADMIN A =====
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true), set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a1', true);
set local role authenticated;

select uji.coba('4.01 admin baca semua profil (>=6 fixture)', $q$select 1 from public.profiles$q$, 'berhasil:%');
select uji.coba('4.02 admin baca transaksi wisata O2', $q$select 1 from public.transaksi where id = '00000000-0000-4000-8000-0000000000f2'$q$, 'berhasil:1');
select uji.coba('4.03 admin baca wisata Nonaktif', $q$select 1 from public.wisata where id = '00000000-0000-4000-8000-0000000000e3'$q$, 'berhasil:1');
select uji.coba('4.04 admin insert wisata', $q$insert into public.wisata (nama, harga, status) values ('UJI admin tambah', 1000, 'Nonaktif')$q$, 'berhasil:1');
select uji.coba('4.05 admin update wisata', $q$update public.wisata set nama = 'UJI Wisata Satu' where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'berhasil:1');
select uji.coba('4.06 admin delete wisata', $q$delete from public.wisata where nama = 'UJI admin tambah'$q$, 'berhasil:1');
select uji.coba('4.07 admin insert buku_kas', $q$insert into public.buku_kas (jenis, kategori, nominal) values ('Pemasukan', 'uji', 1)$q$, 'berhasil:1');
select uji.coba('4.08 admin baca buku_kas', $q$select 1 from public.buku_kas$q$, 'berhasil:%');
select uji.coba('4.09 admin baca tarik_saldo', $q$select 1 from public.tarik_saldo$q$, 'berhasil:%');
select uji.coba('4.10 admin ubah status tarik_saldo', $q$update public.tarik_saldo set status = 'Selesai'$q$, 'berhasil:%');
select uji.coba('4.11 admin baca leads', $q$select 1 from public.leads$q$, 'berhasil:%');
select uji.coba('4.12 admin_set_role valid', $q$select public.admin_set_role('uji-wisatawan2@example.test', 'Owner')$q$, 'berhasil:1');
select uji.coba('4.13 admin_set_role peran ngawur', $q$select public.admin_set_role('uji-wisatawan2@example.test', 'Superuser')$q$, 'galat:22023');
select uji.coba('4.14 admin_set_role email tak ada', $q$select public.admin_set_role('tidak-ada@example.test', 'Owner')$q$, 'galat:P0002');
select uji.coba('4.15 admin_set_langganan', $q$select public.admin_set_langganan('00000000-0000-4000-8000-0000000000b1', 'Aktif')$q$, 'berhasil:1');
select uji.coba('4.16 admin_set_status_transaksi Pending->Berhasil', $q$select public.admin_set_status_transaksi('00000000-0000-4000-8000-0000000000f3', 'Berhasil')$q$, 'berhasil:1');
select uji.coba('4.17 admin tidak mengubah tiket Sudah Digunakan', $q$select public.admin_set_status_transaksi('00000000-0000-4000-8000-0000000000f1', 'Pending')$q$, 'galat:P0002');
select uji.coba('4.18 admin_set_owner_wisata', $q$select public.admin_set_owner_wisata('00000000-0000-4000-8000-0000000000e1', 'uji-owner1@example.test')$q$, 'berhasil:1');
select uji.coba('4.19 admin tidak bisa insert transaksi langsung', $q$insert into public.transaksi (owner_nama, nominal) values ('x', 1)$q$, 'ditolak');
select uji.coba('4.20 admin baca users lama (tertutup)', $q$select 1 from public.users$q$, 'ditolak');
select uji.coba('4.21 admin kelola promo', $q$insert into public.promo (kode, tipe, nilai) values ('UJI20', 'nominal', 20000)$q$, 'berhasil:1');
select uji.coba('4.22 admin tidak bisa mengubah email/role lewat update langsung (hanya RPC)', $q$update public.profiles set role = 'Owner' where id = '00000000-0000-4000-8000-0000000000c1'$q$, 'ditolak');

-- ===== 5. AGEN G (Opsi B) =====
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true), set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000d1', true);
set local role authenticated;

select uji.coba('5.01 agen ajukan_draf valid', $q$select public.ajukan_draf('UJI Mitra Draf', 'Penginapan', 'Padang', 'deskripsi', 100000, 'wifi', '081211112222', array['https://contoh.test/a.jpg'], 'brosur uji', 'izin uji 14 Nov')$q$, 'berhasil:1');
select uji.coba('5.02 agen ajukan_draf tanpa izin_mitra', $q$select public.ajukan_draf('UJI Mitra Draf', null, null, null, null, null, null, null, 'sumber', '')$q$, 'galat:22023');
select uji.coba('5.03 agen ajukan_draf foto bukan https', $q$select public.ajukan_draf('UJI Mitra Draf', null, null, null, null, null, null, array['http://x/a.jpg'], 'sumber', 'izin')$q$, 'galat:22023');
select uji.coba('5.04 agen baca wisata_draf', $q$select 1 from public.wisata_draf$q$, 'kosong');
select uji.coba('5.05 agen update wisata_draf', $q$update public.wisata_draf set status = 'siap_cek'$q$, 'kosong');
select uji.coba('5.06 agen delete wisata_draf', $q$delete from public.wisata_draf$q$, 'kosong');
select uji.coba('5.07 agen insert wisata_draf langsung', $q$insert into public.wisata_draf (nama, sumber, izin_mitra) values ('UJI langsung', 's', 'i')$q$, 'ditolak');
select uji.coba('5.08 agen insert wisata', $q$insert into public.wisata (nama) values ('x')$q$, 'ditolak');
select uji.coba('5.09 agen update wisata', $q$update public.wisata set nama = 'x' where id = '00000000-0000-4000-8000-0000000000e1'$q$, 'kosong');
select uji.coba('5.10 agen setujui_draf', $q$select public.setujui_draf('00000000-0000-4000-8000-0000000000c1')$q$, 'ditolak');

-- ===== 6. ADMIN: setujui draf =====
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true), set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a1', true);
set local role authenticated;

select uji.coba('6.01 admin melihat draf agen', $q$select 1 from public.wisata_draf where nama = 'UJI Mitra Draf'$q$, 'berhasil:1');
select uji.coba('6.02 admin setujui draf -> wisata Nonaktif', $q$select public.setujui_draf((select id from public.wisata_draf where nama = 'UJI Mitra Draf' limit 1))$q$, 'berhasil:1');
select uji.coba('6.03 wisata hasil persetujuan Nonaktif + wa terisi + foto', $q$select 1 from public.wisata where nama = 'UJI Mitra Draf' and status = 'Nonaktif' and wa = '081211112222' and foto = 'https://contoh.test/a.jpg'$q$, 'berhasil:1');

-- ---------- hasil ----------
reset role;
select n, nama, harapan, aktual, lulus from uji.hasil order by n;
select count(*) filter (where lulus) as lulus, count(*) filter (where not lulus) as gagal, count(*) as total from uji.hasil;

rollback;   -- JANGAN ubah menjadi commit
