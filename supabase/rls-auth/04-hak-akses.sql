-- =====================================================================
-- 04-hak-akses.sql
-- Hak tingkat tabel (terpisah dari RLS). Butuh 01-03.
-- Catatan: Fase 1 (13 Nov) sudah mencabut TRUNCATE/TRIGGER/REFERENCES dari
-- anon; REVOKE ALL idempoten dan TIDAK error bila hak sudah tidak ada.
-- Prinsip: anon hampir nol; authenticated hanya hak yang dibutuhkan, sisanya
-- ditahan RLS. Peran service_role tidak disentuh.
-- BELUM DIJALANKAN. Tanpa BEGIN/COMMIT.
-- =====================================================================

-- 1. Cabut semuanya dari anon pada 6 tabel lama + tabel baru + users lama.
revoke all on table public.wisata, public.users, public.transaksi, public.buku_kas,
                    public.tarik_saldo, public.leads, public.profiles, public.promo
  from anon;

-- 2. Cabut semuanya dari authenticated, lalu beri ulang secukupnya.
revoke all on table public.wisata, public.users, public.transaksi, public.buku_kas,
                    public.tarik_saldo, public.leads, public.profiles, public.promo
  from authenticated;

-- 3. anon: hanya baca wisata (baris Aktif oleh RLS) dan menambah leads.
grant select on public.wisata to anon;
grant insert on public.leads  to anon;

-- 4. authenticated (RLS yang membatasi per baris):
grant select, insert, update, delete on public.wisata  to authenticated;   -- tulis hanya lolos untuk admin (RLS)
grant select                         on public.transaksi to authenticated; -- tulis lewat RPC
grant select, insert, update, delete on public.buku_kas to authenticated;  -- admin saja (RLS)
grant select, insert, update         on public.tarik_saldo to authenticated;
grant select, insert                 on public.leads to authenticated;
grant select                         on public.profiles to authenticated;
grant update (nama, username, wa)    on public.profiles to authenticated;  -- BUKAN role/status_langganan/email/id
grant select, insert, update, delete on public.promo to authenticated;     -- admin saja (RLS)
-- public.users (lama): tidak ada hak sama sekali untuk anon/authenticated.

-- 5. Tabel/fungsi BARU di schema public tidak otomatis terbuka.
--    (berlaku untuk objek yang dibuat peran yang menjalankan perintah ini, biasanya postgres)
alter default privileges in schema public revoke all on tables    from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from public, anon, authenticated;
