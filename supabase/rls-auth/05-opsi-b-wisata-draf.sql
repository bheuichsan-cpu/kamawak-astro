-- =====================================================================
-- 05-opsi-b-wisata-draf.sql
-- Opsi B (disetujui 13 Nov): tabel terpisah wisata_draf + ajukan_draf (hanya
-- akun berperan 'Agen') + setujui_draf (hanya admin). Butuh 01 dan 02
-- (memakai public.profiles dan fungsi is_agen/is_admin).
-- Mengikuti KW-panduan-kunci-draf-supabase.md dan rencana §5.
-- Cara membuat akun agen: daftar biasa lewat situs/Auth (akun khusus, bukan
-- akun admin/owner) lalu admin menjalankan admin_set_role('<email>', 'Agen').
-- BELUM DIJALANKAN. Tanpa BEGIN/COMMIT.
-- =====================================================================

create table if not exists public.wisata_draf (
  id           uuid primary key default gen_random_uuid(),
  nama         text not null check (length(nama) between 3 and 120),
  kategori     text,
  lokasi       text,
  deskripsi    text check (length(deskripsi) <= 2000),
  harga_mulai  numeric check (harga_mulai >= 0),
  fasilitas    text,
  wa_usaha     text,
  foto_url     text[] check (foto_url is null or array_length(foto_url, 1) <= 10),
  sumber       text not null,
  izin_mitra   text not null,
  status       text not null default 'draf' check (status in ('draf', 'siap_cek', 'ditolak', 'disetujui')),
  label_uji    boolean not null default false,
  wisata_id    uuid references public.wisata (id) on delete set null,   -- terisi saat disetujui
  diajukan_oleh uuid references public.profiles (id) on delete set null,
  dibuat_pada  timestamptz not null default now()
);

-- Kunci SEKARANG: RLS nyala, tanpa hak untuk anon/authenticated kecuali admin.
alter table public.wisata_draf enable row level security;
revoke all on table public.wisata_draf from public, anon, authenticated;

drop policy if exists wisata_draf_admin on public.wisata_draf;
create policy wisata_draf_admin on public.wisata_draf
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));
grant select, update, delete on public.wisata_draf to authenticated;   -- hanya lolos untuk admin (RLS); tidak ada INSERT langsung

-- ---------------------------------------------------------------------
-- ajukan_draf: satu-satunya jalan masuk agen. Status DIPAKSA 'draf'.
-- Mengembalikan hanya id draf.
-- ---------------------------------------------------------------------
create or replace function public.ajukan_draf(
  p_nama       text,
  p_kategori   text,
  p_lokasi     text,
  p_deskripsi  text,
  p_harga      numeric,
  p_fasilitas  text,
  p_wa         text,
  p_foto       text[],
  p_sumber     text,
  p_izin       text,
  p_uji        boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id  uuid;
  f     text;
begin
  if auth.uid() is null or not public.is_agen() then
    raise exception 'Hanya akun agen' using errcode = '42501';
  end if;
  if btrim(coalesce(p_nama, '')) = '' or btrim(coalesce(p_sumber, '')) = '' or btrim(coalesce(p_izin, '')) = '' then
    raise exception 'nama, sumber, dan izin_mitra wajib diisi' using errcode = '22023';
  end if;
  if p_foto is not null then
    if array_length(p_foto, 1) > 10 then raise exception 'Foto maksimal 10' using errcode = '22023'; end if;
    foreach f in array p_foto loop
      if f is null or f !~ '^https://' or length(f) > 1000 or position('|||' in f) > 0 then
        raise exception 'Tautan foto harus https dan tanpa pemisah |||' using errcode = '22023';
      end if;
    end loop;
  end if;

  insert into public.wisata_draf
    (nama, kategori, lokasi, deskripsi, harga_mulai, fasilitas, wa_usaha, foto_url,
     sumber, izin_mitra, label_uji, status, diajukan_oleh)
  values
    (btrim(p_nama), p_kategori, p_lokasi, p_deskripsi, p_harga, p_fasilitas, p_wa, p_foto,
     btrim(p_sumber), btrim(p_izin), coalesce(p_uji, false), 'draf', auth.uid())   -- status dipaksa
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------
-- setujui_draf: admin memindahkan draf ke wisata. Status wisata awal
-- 'Nonaktif' (disembunyikan situs) sampai admin mengaktifkannya sendiri;
-- boleh 'Aktif' bila admin menyatakan. Wajib punya wa_usaha. Ulasan contoh
-- tidak ikut (tidak ada kolom ulasan).
-- Pemetaan: harga_mulai->harga, foto_url[]->foto (gabung '|||'), wa_usaha->wa.
-- ---------------------------------------------------------------------
create or replace function public.setujui_draf(p_id uuid, p_status text default 'Nonaktif')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  d      record;
  v_wid  uuid;
begin
  if not public.is_admin() then raise exception 'Hanya admin' using errcode = '42501'; end if;
  if p_status not in ('Nonaktif', 'Aktif') then
    raise exception 'Status awal harus Nonaktif atau Aktif' using errcode = '22023';
  end if;
  select * into d from public.wisata_draf where id = p_id for update;
  if not found then raise exception 'Draf tidak ditemukan' using errcode = 'P0002'; end if;
  if d.status in ('disetujui', 'ditolak') then
    raise exception 'Draf sudah diproses' using errcode = '22023';
  end if;
  if btrim(coalesce(d.wa_usaha, '')) = '' then
    raise exception 'wa_usaha mitra wajib diisi sebelum disetujui' using errcode = '22023';
  end if;

  insert into public.wisata (nama, lokasi, kategori, harga, foto, wa, status, deskripsi, fasilitas)
  values (
    d.nama, d.lokasi, d.kategori, d.harga_mulai,
    case when d.foto_url is null then null else array_to_string(d.foto_url, '|||') end,
    d.wa_usaha, p_status, d.deskripsi, d.fasilitas
  )
  returning id into v_wid;

  update public.wisata_draf set status = 'disetujui', wisata_id = v_wid where id = d.id;
  return v_wid;
end;
$$;

revoke all on function public.ajukan_draf(text, text, text, text, numeric, text, text, text[], text, text, boolean) from public, anon, authenticated;
revoke all on function public.setujui_draf(uuid, text) from public, anon, authenticated;
grant execute on function public.ajukan_draf(text, text, text, text, numeric, text, text, text[], text, text, boolean) to authenticated;  -- cek is_agen() di dalam
grant execute on function public.setujui_draf(uuid, text) to authenticated;                                                              -- cek is_admin() di dalam
