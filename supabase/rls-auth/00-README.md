# Perbaikan keamanan Supabase Kamawak (RLS + Supabase Auth)

Status: **DRAF, belum ada satu pun SQL yang dijalankan** di database mana pun, dan tidak ada yang diuji terhadap Postgres sungguhan (tidak ada Postgres/Supabase CLI di mesin penyusun). Semua SQL harus lolos `99-dry-run.sql` dan `06-matriks-uji.sql` di proyek uji sebelum produksi. Rujukan: `KW-rencana-perbaikan-rls.md` (§1, §2, §4, §5, §6).

Tidak ada kunci/sandi di folder ini. Jangan menambahkannya.

## Isi folder

| Berkas | Fungsi |
|---|---|
| `01-profiles-fungsi.sql` | Tabel `profiles` + trigger dari `auth.users`, fungsi `is_admin/is_mitra/is_agen/is_owner_of`, kolom baru (`wisata.owner_id`, kolom pemesanan di `transaksi`, `tarik_saldo.owner_id`), tabel `promo`. Tabel baru langsung dikunci. |
| `02-rpc.sql` | RPC: `buat_transaksi`, `checkin_tiket`, `ajukan_mitra`, `admin_set_role`, `admin_set_langganan`, `admin_set_status_transaksi`, `admin_set_owner_wisata`, `cari_email`, `username_tersedia`, `catat_lead`. |
| `03-kebijakan-rls.sql` | Hapus kebijakan lama, buat kebijakan per tabel, **nyalakan RLS paling akhir**. |
| `04-hak-akses.sql` | `revoke` dari anon/authenticated, `grant` minimal, default privileges. |
| `05-opsi-b-wisata-draf.sql` | `wisata_draf`, `ajukan_draf` (hanya peran `Agen`), `setujui_draf` (hanya admin). |
| `06-matriks-uji.sql` | ±130 uji akses (anon, wisatawan, owner, admin, agen) dalam `begin ... rollback`. |
| `07-mundur.sql` | Mundur berpasangan dengan 03/04 (+ bagian B dikomentari untuk membuang objek baru). |
| `99-dry-run.sql` | `begin; 01-05; rollback;` untuk uji sintaks tanpa efek. **Jangan diubah jadi commit.** |

## Prasyarat di dasbor Supabase (Abay)

1. **Authentication > Providers > Email: "Confirm email" = ON.** WAJIB. Pewarisan peran dari akun lama hanya aman bila email harus dikonfirmasi (lihat 01 bagian 3).
2. **Authentication > Email Templates > "Confirm signup"**: tambahkan `{{ .Token }}` agar email membawa kode 6 digit (UI daftar memakai OTP; tautan bawaan tetap berfungsi). Panjang OTP default 6 (UI membatasi 6 digit).
3. **Authentication > URL Configuration**: Site URL = `https://kamawak.id`; Redirect URLs menyertakan `https://kamawak.id/atur-sandi` dan `https://kamawak.id/login` (dan alamat pratinjau Cloudflare untuk uji). Template "Reset Password" bawaan sudah cukup.
4. **SMTP**: email bawaan Supabase sangat dibatasi (beberapa email/jam) dan tidak cocok untuk 6 pengguna yang menyetel ulang sandi sekaligus + pendaftar baru. Pasang SMTP sendiri sebelum cutover (keputusan Abay).
5. Backup terakhir (rencana §4 langkah 0/10) sudah diambil.
6. Cek sebelum cutover (baca saja, hasil angka):
   - `select status, count(*) from public.wisata group by 1;` Setelah 03, publik hanya melihat `status = 'Aktif'` persis (huruf besar-kecil). Bila ada `aktif`/`AKTIF`/spasi atau status lain yang seharusnya tayang, rapikan dulu.
   - `select count(*) filter (where email is null or btrim(email) = '') as tanpa_email, count(*) as total from public.users;` pengguna tanpa email tidak bisa dibuatkan akun Auth otomatis.

## Urutan penerapan dan pelaksana

SQL dijalankan oleh Abay/Doraemon (G3), bukan agen. Tiap berkas dijalankan utuh, berurutan. Disarankan lewat `psql -v ON_ERROR_STOP=1 -1 -f <berkas>` (satu transaksi per berkas); di SQL Editor Supabase tempel utuh dan lihat galat.

| # | Langkah | Siapa | Hasil yang diharapkan |
|---|---|---|---|
| A | Proyek UJI: jalankan `99-dry-run.sql`, lalu 01..05 sungguhan, lalu `06-matriks-uji.sql` | Abay/Doraemon | Dry-run tanpa galat dan `select to_regclass('public.profiles')` = null setelahnya; matriks: **semua baris `lulus = true`** |
| B | Pratinjau Cloudflare dari cabang `fix/rls-auth` menunjuk ke proyek uji; uji alur daftar/masuk/ganti sandi/booking/check-in/admin | Abay + Codex | Semua alur §4 langkah 9 rencana jalan |
| C | **Produksi, sebelum jeda (tidak mengganggu situs):** jalankan `99-dry-run.sql` di produksi (seluruhnya dibatalkan) | Abay/Doraemon | Tanpa galat |
| D | **Mulai jeda.** Umumkan, backup lagi | Abay | |
| E | Jalankan `01` dan `02` di produksi | Abay/Doraemon | Tanpa galat; tabel `profiles` ada (kosong), RLS tabel lama masih mati (situs lama masih jalan) |
| F | Buat akun Auth untuk 6 pengguna (lihat bagian di bawah) dan konfirmasikan | Abay | `select email, role, status_langganan from public.profiles;` memuat 6 baris dengan peran benar (minimal 1 Admin) |
| G | `select public.backfill_owner_id();` (peran postgres) | Abay/Doraemon | Angka = jumlah wisata yang terpetakan ke pemilik; sisanya `owner_id` null, tetapkan dengan `admin_set_owner_wisata` |
| H | Jalankan `05` bila Opsi B ikut cutover | Abay/Doraemon | |
| I | Jalankan `03` lalu `04` | Abay/Doraemon | Mulai sini situs LAMA tidak bisa login/tulis; segera lanjut J |
| J | Merge `fix/rls-auth` ke `main` (Cloudflare Pages deploy otomatis), bangun ulang APK | Abay/Codex | Situs baru hidup |
| K | Jalankan `06-matriks-uji.sql` di produksi (rollback otomatis) lalu uji asap manual sebagai anon/wisatawan/owner/admin | Abay | Semua `lulus`; cabut jeda |
| L | Setelah stabil >= 7 hari: kolom `users.password` dan tabel `public.users` lama dibuang (pindahkan skema tersimpan dulu) | Abay | Rencana §4 langkah 15 |

Catatan: `warisi_legacy` membaca `public.users` lama untuk mewarisi nama/username/WA/peran/status langganan; **jangan membuang tabel itu sebelum semua pengguna aktif sudah mengaktifkan akun Auth-nya.**

## 6 pengguna lama: membuat akun Auth (tanpa menyalin sandi)

Sandi lama (SHA-256/teks biasa) tidak bisa diimpor. Untuk tiap pengguna yang punya email di `public.users`:
1. Dashboard > Authentication > Users > **Invite user** (atau Add user tanpa sandi) memakai email yang sama dengan `users.email`.
2. Pengguna membuka tautan undangan/atur ulang dan menetapkan sandi (atau memakai `/atur-sandi` di situs baru).
3. Saat email terkonfirmasi, trigger menyalin nama, username, WA, peran dan status langganan dari baris lama dengan email sama (hanya sekali).
4. **Admin pertama** (jaring pengaman bila pewarisan gagal), dijalankan peran postgres, ganti placeholder dengan email Abay: `update public.profiles set role = 'Admin' where lower(email) = lower('<EMAIL-ADMIN>');`
5. Pengguna tanpa email: minta email dulu, atau Abay membuat akun undangan dengan email yang diberikan lalu `admin_set_role`/`admin_set_langganan` dari halaman admin atau SQL Editor.

Admin menaikkan peran selanjutnya lewat halaman admin (memanggil `admin_set_role`).

## Cara mundur

Hanya berpasangan: **SQL (07 bagian A) bersama Rollback deploy Cloudflare ke deployment sebelumnya.** Jangan salah satu saja (situs baru butuh RLS+RPC, situs lama butuh RLS mati).
- Sebelum 03/04 dijalankan: tidak ada yang perlu dimundurkan selain `07` bagian B (opsional) bila rencana batal.
- Sesudah 03/04: jalankan `07-mundur.sql` bagian A. Data tidak berubah; objek baru tetap ada tetapi tidak dipakai. Risiko lama terbuka lagi selama mundur.
- Bagian B (dikomentari) menghapus `profiles`, kolom pemesanan, `wisata_draf`, RPC: hapus data baru. Hanya bila batal total.
- Selama jeda situs tidak boleh menerima transaksi baru (hindari baris yatim di dua skema).

## Perubahan perilaku yang perlu diketahui (bukan sekadar teknis)

- **`transaksi` produksi tidak punya kolom pemesanan** (hanya `owner_nama, nominal, rekening, status, created_at`), sedangkan checkout lama menulis kolom lain; jadi checkout lama kemungkinan tidak pernah berhasil di produksi (tabel kosong). 01 menambahkan kolom yang dibutuhkan (`wisata_id, user_id, nama_pemesan, "namaProduk", tanggal, pax, paket, "rawVarian", "totalBayar", diskon, promo_kode, waktu_checkin`). ID tiket sekarang uuid dari server (bukan `TRX-<timestamp>`).
- **Status awal pesanan 'Pending'**, bukan 'Berhasil'. Saldo mitra dan statistik hanya menghitung `Berhasil`/`Sudah Digunakan`, dan check-in menolak tiket `Pending`. Menandai lunas: `admin_set_status_transaksi(<id>, 'Berhasil')` (belum ada tombolnya di halaman admin) atau gateway pembayaran nanti. Pesan sukses di `pdp.astro` sudah diubah agar jujur.
- **Kupon divalidasi server** dari tabel `promo` (kosong). Kupon yang hanya ada di localStorage/Apps Script tidak akan diterima server ("Kupon tidak dikenali") sampai dimasukkan ke `promo` (insert oleh admin lewat SQL Editor; belum ada UI).
- Tambahan harga VIP 250000 dan format varian `Nama:tambahan,Nama2:tambahan` ditiru dari `pdp.astro`. Jika ketentuan itu diubah di salah satu sisi, ubah keduanya.
- Pengguna baru tidak lagi otomatis `status_langganan = 'Aktif'` (null); sebelumnya semua pendaftar tampil di daftar "Akun Mitra" admin.
- Beranda kini hanya menampilkan wisata `Aktif` (RLS), bukan "selain Nonaktif".
- Halaman owner: saldo/riwayat/leads dihitung dari wisata yang `owner_id`-nya akun itu; wisata yang belum terpetakan tidak terhitung (lihat langkah G).
- Tarik saldo: nominal tidak dibandingkan dengan saldo di database; admin menyetujui. Kesalahan insert sekarang ditampilkan (sebelumnya selalu "berhasil (simulasi)").

## Yang tidak bisa dijamin dari berkas ini (asumsi / belum diuji)

- Tidak ada satu pun SQL yang dijalankan atau di-parse; typo sintaks mungkin ada. `99-dry-run.sql` ada untuk itu.
- Pembuatan trigger pada `auth.users` dan fixture `insert into auth.users` di 06 mengandalkan peran SQL Editor memiliki hak itu dan kolom `auth.users` versi Supabase terpasang; belum diverifikasi.
- Nilai `platform` leads (`wa, ig, fb, tiktok`) adalah asumsi (tidak ada kode yang menulis `leads`).
- `cari_email` membuka email berdasarkan username/WA/nama (enumerasi) dan tidak ada pembatasan laju; pembatasan laju butuh Edge Function atau WAF.
- Batas "20 pesanan Pending/jam" dan "30 lead/jam" bersifat dasar, bukan anti-penyalahgunaan penuh.
- Default privileges sebelum 04 tidak tercatat di backup; `07` tidak memulihkannya otomatis.
