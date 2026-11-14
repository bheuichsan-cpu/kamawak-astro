-- =====================================================================
-- 99-dry-run.sql
-- Uji sintaks 01-05 di database yang berisi data nyata TANPA efek.
--
--  *** JANGAN UBAH rollback MENJADI commit. ***
--
-- Dasar: DDL di PostgreSQL bersifat transaksional. ROLLBACK membatalkan
-- penuh semua CREATE/ALTER/GRANT/POLICY/TRIGGER di dalam transaksi ini
-- (tabel, kolom, fungsi, kebijakan, hak, enable RLS). Batasan: perintah
-- yang butuh peran lebih tinggi (mis. trigger di auth.users) akan gagal
-- dengan jelas, dan itu justru informasi yang dicari. Kunci tabel
-- (ACCESS EXCLUSIVE) ditahan singkat selama transaksi berjalan.
--
-- CARA PAKAI
-- (a) psql (satu transaksi, berhenti di galat pertama), dari folder ini:
--       psql "<URL koneksi>" -v ON_ERROR_STOP=1 -f 99-dry-run.sql
--     Baris \i di bawah hanya jalan di psql.
-- (b) SQL Editor Supabase: tidak mendukung \i. Gabungkan dulu:
--       { echo 'begin;'; cat 01-profiles-fungsi.sql 02-rpc.sql 03-kebijakan-rls.sql \
--           04-hak-akses.sql 05-opsi-b-wisata-draf.sql; echo 'rollback;'; } > "$TMPDIR/dry-run-gabungan.sql"
--     lalu tempel isinya ke editor. Berkas gabungan itu sendiri tidak memuat commit.
--
-- Hasil yang diharapkan: tanpa galat; lalu verifikasi bahwa tidak ada
-- yang tersisa:
--   select to_regclass('public.profiles');   -- harus null
-- =====================================================================
begin;

\i 01-profiles-fungsi.sql
\i 02-rpc.sql
\i 03-kebijakan-rls.sql
\i 04-hak-akses.sql
\i 05-opsi-b-wisata-draf.sql

rollback;
