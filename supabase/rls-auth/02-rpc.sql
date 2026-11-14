-- =====================================================================
-- 02-rpc.sql
-- Fungsi RPC untuk aksi sensitif. Semua SECURITY DEFINER dengan
-- set search_path = '' (semua objek ditulis lengkap public./auth.).
-- Akses: revoke dari public/anon/authenticated, lalu grant ke peran tepat.
-- Kode error: 42501 = tidak berwenang, 22023 = parameter tidak valid,
-- P0002 = data tidak ditemukan/tidak tersedia, 54000 = batas dilampaui.
-- BELUM DIJALANKAN. Butuh 01 sudah diterapkan. Tanpa BEGIN/COMMIT.
-- =====================================================================

-- ---------------------------------------------------------------------
-- cari_email(identitas) : untuk login memakai username / WA / nama.
-- anon boleh. Mengembalikan HANYA email (atau null). Isian yang mengandung
-- '@' dikembalikan apa adanya tanpa menyentuh tabel.
-- CATATAN RISIKO: orang yang tahu username/WA bisa mengetahui emailnya
-- (enumerasi). Tidak ada pembatasan laju di sini (butuh Edge Function/WAF).
-- ---------------------------------------------------------------------
create or replace function public.cari_email(p_identitas text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  x   text := lower(btrim(coalesce(p_identitas, '')));
  arr text[];
begin
  if x = '' or length(x) > 200 then return null; end if;
  if position('@' in x) > 0 then return x; end if;

  select array_agg(p.email) into arr from public.profiles p
   where p.username is not null and lower(p.username) = x and p.email is not null;
  if arr is not null and array_length(arr, 1) = 1 then return arr[1]; end if;

  if x ~ '^[0-9+ ()-]+$' and public.norm_wa(x) is not null then
    select array_agg(p.email) into arr from public.profiles p
     where public.norm_wa(p.wa) = public.norm_wa(x) and p.email is not null;
    if arr is not null and array_length(arr, 1) = 1 then return arr[1]; end if;
  end if;

  select array_agg(p.email) into arr from public.profiles p
   where lower(btrim(coalesce(p.nama, ''))) = x and p.email is not null;
  if arr is not null and array_length(arr, 1) = 1 then return arr[1]; end if;

  return null;
end;
$$;

-- username_tersedia(username) : cek sebelum mendaftar. anon boleh.
create or replace function public.username_tersedia(p_username text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles p
     where p.username is not null and lower(p.username) = lower(btrim(coalesce(p_username, '')))
  )
$$;

-- ---------------------------------------------------------------------
-- catat_lead(wisata, platform) : klik WA/IG/FB/TikTok. anon boleh.
-- Batas sederhana: maks 30 catatan per wisata+platform per jam.
-- ---------------------------------------------------------------------
create or replace function public.catat_lead(p_wisata uuid, p_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_platform is null or p_platform not in ('wa', 'ig', 'fb', 'tiktok') then
    raise exception 'Platform tidak valid' using errcode = '22023';
  end if;
  if not exists (select 1 from public.wisata w where w.id = p_wisata and w.status = 'Aktif') then
    raise exception 'Wisata tidak tersedia' using errcode = 'P0002';
  end if;
  if (select count(*) from public.leads l
       where l.wisata_id = p_wisata and l.platform = p_platform
         and l.created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Batas pencatatan tercapai' using errcode = '54000';
  end if;
  insert into public.leads (wisata_id, platform) values (p_wisata, p_platform);
end;
$$;

-- ---------------------------------------------------------------------
-- buat_transaksi : harga dihitung di server dari tabel wisata (+ varian
-- + paket + kupon dari tabel promo). Status awal 'Pending'.
-- Aturan harga meniru pdp.astro: (harga + tambahan) * pax - diskon;
-- tambahan = angka setelah ':' pada item varian yang dipilih; jika wisata
-- tidak punya varian dan paket 'vip' maka tambahan 250000 (tetap, sama
-- dengan konstanta tambahanVIP di pdp.astro).
-- ---------------------------------------------------------------------
create or replace function public.buat_transaksi(
  p_wisata     uuid,
  p_tanggal    date,
  p_pax        integer,
  p_paket      text default 'reguler',
  p_raw_varian text default '',
  p_kupon      text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_nama    text;
  w         record;
  pr        record;
  item      text;
  v_tambah  numeric := 0;
  v_ketemu  boolean := false;
  v_sub     numeric;
  v_diskon  numeric := 0;
  v_total   numeric;
  v_id      uuid;
  v_paket   text := lower(btrim(coalesce(p_paket, 'reguler')));
  v_raw     text := btrim(coalesce(p_raw_varian, ''));
  v_kupon   text := btrim(coalesce(p_kupon, ''));
begin
  if v_uid is null then raise exception 'Harus login' using errcode = '42501'; end if;
  select p.nama into v_nama from public.profiles p where p.id = v_uid;
  if not found then raise exception 'Profil tidak ditemukan' using errcode = '42501'; end if;

  if p_pax is null or p_pax < 1 or p_pax > 50 then
    raise exception 'Jumlah peserta tidak valid (1-50)' using errcode = '22023';
  end if;
  if p_tanggal is null or p_tanggal < (now() at time zone 'Asia/Jakarta')::date then
    raise exception 'Tanggal tidak valid' using errcode = '22023';
  end if;
  if v_paket not in ('reguler', 'vip') then
    raise exception 'Paket tidak valid' using errcode = '22023';
  end if;

  select * into w from public.wisata x where x.id = p_wisata and x.status = 'Aktif';
  if not found then raise exception 'Produk tidak tersedia' using errcode = 'P0002'; end if;
  if coalesce(w.harga, 0) <= 0 then raise exception 'Harga produk belum diatur' using errcode = '22023'; end if;

  if (select count(*) from public.transaksi t
       where t.user_id = v_uid and t.status = 'Pending'
         and t.created_at > now() - interval '1 hour') >= 20 then
    raise exception 'Terlalu banyak pesanan tertunda' using errcode = '54000';
  end if;

  if btrim(coalesce(w.varian, '')) <> '' then
    if v_paket = 'vip' then raise exception 'Paket tidak valid untuk produk ini' using errcode = '22023'; end if;
    if v_raw <> '' then
      foreach item in array string_to_array(w.varian, ',') loop
        if btrim(item) = v_raw then
          v_ketemu := true;
          if btrim(split_part(item, ':', 2)) ~ '^[0-9]+(\.[0-9]+)?$' then
            v_tambah := btrim(split_part(item, ':', 2))::numeric;
          end if;
          exit;
        end if;
      end loop;
      if not v_ketemu then raise exception 'Varian tidak valid' using errcode = '22023'; end if;
    end if;
  else
    v_raw := '';
    if v_paket = 'vip' then v_tambah := 250000; end if;
  end if;

  v_sub := (w.harga + v_tambah) * p_pax;

  if v_kupon <> '' then
    select * into pr from public.promo k where upper(k.kode) = upper(v_kupon) and k.aktif;
    if not found then raise exception 'Kupon tidak dikenali' using errcode = '22023'; end if;
    if v_sub < pr.minimal then raise exception 'Belum memenuhi minimal transaksi kupon' using errcode = '22023'; end if;
    v_diskon := case when pr.tipe = 'persen' then round(v_sub * pr.nilai / 100) else pr.nilai end;
    v_diskon := least(v_diskon, v_sub);
  end if;
  v_total := greatest(0, v_sub - v_diskon);

  insert into public.transaksi (
    owner_nama, nominal, status,
    wisata_id, user_id, nama_pemesan, "namaProduk", tanggal, pax, paket, "rawVarian",
    "totalBayar", diskon, promo_kode
  ) values (
    coalesce(nullif(btrim(w.owner), ''), 'Admin'), v_total, 'Pending',
    w.id, v_uid, v_nama, w.nama, p_tanggal, p_pax, v_paket, v_raw,
    v_total, v_diskon, nullif(v_kupon, '')
  )
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'total', v_total, 'diskon', v_diskon, 'status', 'Pending');
end;
$$;

-- ---------------------------------------------------------------------
-- checkin_tiket(kode) : hanya pemilik wisata tiket itu (atau admin).
-- hasil: ok | sudah_digunakan | dibatalkan | belum_dibayar | tidak_ditemukan
-- Tiket 'Pending' (belum dikonfirmasi bayar) TIDAK bisa check-in.
-- ---------------------------------------------------------------------
create or replace function public.checkin_tiket(p_kode text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_kode uuid;
  t      record;
  v_st   text;
  v_hasil text;
  v_status text;
  v_waktu  timestamptz;
begin
  if v_uid is null then raise exception 'Harus login' using errcode = '42501'; end if;
  begin
    v_kode := btrim(coalesce(p_kode, ''))::uuid;
  exception when others then
    return jsonb_build_object('hasil', 'tidak_ditemukan');
  end;

  select * into t from public.transaksi x where x.id = v_kode for update;
  if not found or not (public.is_owner_of(t.wisata_id) or public.is_admin()) then
    return jsonb_build_object('hasil', 'tidak_ditemukan');   -- tidak membocorkan tiket milik pihak lain
  end if;

  v_status := t.status;
  v_waktu  := t.waktu_checkin;
  v_st := lower(coalesce(t.status, ''));
  if v_st like '%digunakan%' or v_st like '%checked-in%' then
    v_hasil := 'sudah_digunakan';
  elsif v_st like '%batal%' or v_st like '%gagal%' then
    v_hasil := 'dibatalkan';
  elsif v_st <> 'berhasil' then
    v_hasil := 'belum_dibayar';
  else
    update public.transaksi set status = 'Sudah Digunakan', waktu_checkin = now() where id = t.id
    returning status, waktu_checkin into v_status, v_waktu;
    v_hasil := 'ok';
  end if;

  return jsonb_build_object(
    'hasil', v_hasil,
    'tiket', jsonb_build_object(
      'id', t.id, 'status', v_status, 'namaProduk', t."namaProduk", 'nama_pemesan', t.nama_pemesan,
      'tanggal', t.tanggal, 'pax', t.pax, 'paket', t.paket, 'totalBayar', t."totalBayar",
      'waktu_checkin', v_waktu)
  );
end;
$$;

-- ---------------------------------------------------------------------
-- ajukan_mitra(wa, nama_usaha) : pengguna login mengajukan jadi mitra.
-- TIDAK mengubah peran (peran hanya lewat admin_set_role); hanya mengisi
-- wa/nama_usaha dan menandai status_langganan = 'Pending'.
-- ---------------------------------------------------------------------
create or replace function public.ajukan_mitra(p_wa text, p_nama_usaha text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Harus login' using errcode = '42501'; end if;
  if btrim(coalesce(p_wa, '')) = '' or length(p_wa) > 30 then
    raise exception 'Nomor WhatsApp tidak valid' using errcode = '22023';
  end if;
  update public.profiles
     set wa = btrim(p_wa),
         nama_usaha = coalesce(nullif(btrim(left(p_nama_usaha, 150)), ''), nama_usaha),
         status_langganan = 'Pending'
   where id = v_uid;
  if not found then raise exception 'Profil tidak ditemukan' using errcode = 'P0002'; end if;
end;
$$;

-- ---------------------------------------------------------------------
-- Aksi admin
-- ---------------------------------------------------------------------
create or replace function public.admin_set_role(p_email text, p_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target uuid;
  v_role_lama text;
begin
  if not public.is_admin() then raise exception 'Hanya admin' using errcode = '42501'; end if;
  if p_role is null or p_role not in ('Admin', 'Owner', 'Mitra', 'Wisatawan', 'Agen') then
    raise exception 'Peran tidak valid' using errcode = '22023';
  end if;
  select p.id, p.role into v_target, v_role_lama
    from public.profiles p where lower(btrim(p.email)) = lower(btrim(coalesce(p_email, '')));
  if not found then raise exception 'Pengguna tidak ditemukan' using errcode = 'P0002'; end if;
  if v_role_lama = 'Admin' and p_role <> 'Admin'
     and (select count(*) from public.profiles where role = 'Admin') <= 1 then
    raise exception 'Tidak boleh menurunkan admin terakhir' using errcode = '22023';
  end if;
  update public.profiles set role = p_role where id = v_target;
end;
$$;

create or replace function public.admin_set_langganan(p_user uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'Hanya admin' using errcode = '42501'; end if;
  if p_status is null or p_status not in ('Aktif', 'Pending', 'Nonaktif', 'Kadaluarsa') then
    raise exception 'Status tidak valid' using errcode = '22023';
  end if;
  update public.profiles set status_langganan = p_status where id = p_user;
  if not found then raise exception 'Pengguna tidak ditemukan' using errcode = 'P0002'; end if;
end;
$$;

-- Konfirmasi pembayaran manual / pembatalan (belum ada tombolnya di admin.astro;
-- dipanggil dari SQL Editor atau UI baru). Status 'Sudah Digunakan' tidak diubah balik.
create or replace function public.admin_set_status_transaksi(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'Hanya admin' using errcode = '42501'; end if;
  if p_status is null or p_status not in ('Pending', 'Berhasil', 'Batal') then
    raise exception 'Status tidak valid' using errcode = '22023';
  end if;
  update public.transaksi set status = p_status
   where id = p_id and status <> 'Sudah Digunakan';
  if not found then raise exception 'Transaksi tidak ditemukan atau sudah digunakan' using errcode = 'P0002'; end if;
end;
$$;

-- Menetapkan pemilik wisata secara eksplisit (bila pemetaan nama otomatis ambigu).
create or replace function public.admin_set_owner_wisata(p_wisata uuid, p_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_owner uuid;
begin
  if not public.is_admin() then raise exception 'Hanya admin' using errcode = '42501'; end if;
  select p.id into v_owner from public.profiles p
   where lower(btrim(p.email)) = lower(btrim(coalesce(p_email, ''))) and p.role in ('Owner', 'Mitra');
  if not found then raise exception 'Pemilik (Owner/Mitra) tidak ditemukan' using errcode = 'P0002'; end if;
  update public.wisata set owner_id = v_owner where id = p_wisata;
  if not found then raise exception 'Wisata tidak ditemukan' using errcode = 'P0002'; end if;
end;
$$;

-- ---------------------------------------------------------------------
-- Hak eksekusi: cabut semua dulu, beri ke peran yang tepat.
-- ---------------------------------------------------------------------
revoke all on function public.cari_email(text)                                      from public, anon, authenticated;
revoke all on function public.username_tersedia(text)                               from public, anon, authenticated;
revoke all on function public.catat_lead(uuid, text)                                from public, anon, authenticated;
revoke all on function public.buat_transaksi(uuid, date, integer, text, text, text) from public, anon, authenticated;
revoke all on function public.checkin_tiket(text)                                   from public, anon, authenticated;
revoke all on function public.ajukan_mitra(text, text)                              from public, anon, authenticated;
revoke all on function public.admin_set_role(text, text)                            from public, anon, authenticated;
revoke all on function public.admin_set_langganan(uuid, text)                       from public, anon, authenticated;
revoke all on function public.admin_set_status_transaksi(uuid, text)                from public, anon, authenticated;
revoke all on function public.admin_set_owner_wisata(uuid, text)                    from public, anon, authenticated;

grant execute on function public.cari_email(text)                                      to anon, authenticated;
grant execute on function public.username_tersedia(text)                               to anon, authenticated;
grant execute on function public.catat_lead(uuid, text)                                to anon, authenticated;
grant execute on function public.buat_transaksi(uuid, date, integer, text, text, text) to authenticated;
grant execute on function public.checkin_tiket(text)                                   to authenticated;
grant execute on function public.ajukan_mitra(text, text)                              to authenticated;
grant execute on function public.admin_set_role(text, text)                            to authenticated;   -- cek is_admin() di dalam
grant execute on function public.admin_set_langganan(uuid, text)                       to authenticated;
grant execute on function public.admin_set_status_transaksi(uuid, text)                to authenticated;
grant execute on function public.admin_set_owner_wisata(uuid, text)                    to authenticated;
