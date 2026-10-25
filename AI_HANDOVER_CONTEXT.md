# 🚀 KONTEKS PROYEK & PANDUAN HANDOVER AI: KAMAWAK.ID
> **Petunjuk untuk AI di Chat Baru:**  
> Dokumen ini berisi rekam jejak lengkap, arsitektur teknis, struktur file, fitur yang sudah dibuat, dan status terkini dari platform **Kamawak.id**. Baca dokumen ini untuk langsung melanjutkan pengerjaan proyek tanpa kehilangan konteks.

---

## 1. RINGKASAN PROYEK (PROJECT OVERVIEW)
- **Nama Platform:** Kamawak.id (Kamawak)
- **Situs Resmi (Live Production):** `https://kamawak.id`
- **Fokus & Industri:** Online Travel Agent (OTA) & Direktori Pariwisata Terpadu Provinsi Sumatera Barat (Padang, Bukittinggi, Lembah Harau, Danau Kembar, Alahan Panjang, Kawasan Mandeh, Kepulauan Mentawai, Solok, Pariaman, dll.).
- **Fungsi Utama:**
  1. Direktori & reservasi wisata: Penginapan (villa, glamping, homestay), Tur & Tiket atraksi, Rental mobil/motor, Jasa Dokumentasi/Foto Drone, Kuliner, dan Oleh-Oleh khas Minang.
  2. Portal Mitra Pemilik Usaha lokal untuk mendaftar, mempromosikan unit usaha, dan menerima reservasi via WhatsApp / Dashboard.
  3. Sistem E-Tiket ber-QR Code untuk wisatawan.
- **Lokasi Proyek Lokal:** `/Volumes/Abay Doc/kamawak-astro`
- **Repository Git:** `https://github.com/bheuichsan-cpu/kamawak-astro.git` (Branch utama: `main`)
- **Hosting & Deployment:** Cloudflare Pages (Otomatis mendeploy setiap ada `git push origin main`).

---

## 2. STACK TEKNOLOGI & ARSITEKTUR
- **Frontend Framework:** Astro 5.x (Static Site Generation / High Performance HTML)
- **Styling:** Tailwind CSS & Modern CSS Custom Properties (`--primary: #FF5E1F;`)
- **Mobile Wrapper:** Capacitor 6 (Android App dengan sync aset web ke `android/`)
- **Database & Backend:**
  - Supabase (PostgreSQL, Supabase Auth, Storage)
  - `src/components/GASPolyfill.astro`: Lapisan transisi polyfill dari arsitektur lama Google Apps Script (GAS) menuju REST API Supabase murni.
- **Icon & UI Framework:** FontAwesome 6, SweetAlert2, Google Fonts (Poppins & Inter)
- **Automasi CI/CD:** GitHub Actions (`.github/workflows/build-apk.yml`) untuk build file APK Android otomatis di cloud.

---

## 3. STRUKTUR DIREKTORI & HALAMAN UTAMA (`src/pages/`)

| Halaman | Rute Web | Deskripsi & Fitur Utama |
|---|---|---|
| `src/pages/index.astro` | `/` | **Beranda Utama:** Hero banner keindahan Sumbar, running text promo, floating smart search filter, 4x2 mobile category bubbles, dynamic ad carousel space, shortcut kota wisata, katalog produk dengan badge diskon & bookmark favorit, floating WhatsApp CS. |
| `src/pages/pdp.astro` | `/pdp?id=...` | **Halaman Detail Produk (PDP):** Galeri foto interaktif, fasilitas, deskripsi lengkap, rating & ulasan, pemilih varian paket, form booking tanggal & pax, kalkulator diskon kupon, tombol pesan langsung ke WhatsApp pemilik. |
| `src/pages/login.astro` | `/login` | **Portal Masuk & Daftar Akun:** Tab toggle Masuk / Daftar, pemilihan peran (Wisatawan vs Pemilik Usaha/Mitra), validasi nomor WhatsApp, hashing keamanan lokal, integrasi Supabase Auth. |
| `src/pages/profil.astro` | `/profil` | **Profil Wisatawan & Tiket:** Terbagi menjadi 2 tab terpisah: Tab **Akun Profil** (foto profil, nomor WhatsApp, edit profil, hubungi CS, logout) dan Tab **Tiket Saya** (daftar riwayat e-tiket dengan QR Code digital). |
| `src/pages/admin.astro` | `/admin` | **Dashboard CMS Superadmin:** Verifikasi mitra baru, persetujuan listing wisata, kelola banner iklan sponsor, sanitasi cache dan statistik platform. |
| `src/pages/owner.astro` | `/owner` | **Dashboard Mitra Pemilik Usaha:** Kelola katalog villa/tur milik sendiri, pantau status reservasi tamu masuk. |
| `src/pages/polling.astro` | `/polling` | **Halaman Polling Logo Publik:** Showcase variasi logo resmi Kamawak untuk voting pengguna interaktif. |
| `src/components/BottomNav.astro` | - | Navigasi bawah melayang (*floating bottom navbar*) khusus tampilan mobile smartphone. |

---

## 4. BRAND IDENTITY & LOGO RESMI
- **Logo Resmi:** Monogram huruf **"K"** Modern *Extra-Bold*.
  - Batang tegak kokoh tebal melambangkan keandalan platform.
  - Sayap atas terinspirasi dari lekukan atap **Gonjong Rumah Gadang**.
  - Kaki bawah melangkah maju melambangkan kemajuan pariwisata Ranah Minang.
  - Titik oranye/putih di sudut kanan melambangkan matahari terbit Ranah Minang sekaligus domain **.id**.
- **Warna Utama:** Oranye Khas Kamawak (`#FF5E1F` gradasi ke `#D93800`), Putih Bersih (`#FFFFFF`), Dark Slate (`#0F172A`).

---

## 5. OPTIMASI SEO & FAVICON SUITE (STATUS TERAKHIR)
Seluruh aset ikon telah dirender ulang secara presisi dari vektor SVG asli menggunakan Google Chrome Headless Renderer (100% *full-bleed*, tanpa bingkai putih kosong, sudut luar transparan rapi):

- `public/favicon.svg` : Vektor SVG utama dengan atribut `sizes="any"`.
- `public/favicon-16x16.png` & `favicon-32x32.png` : Resolusi khusus tab Chrome & browser desktop agar tidak mengecil.
- `public/favicon-48x48.png` & `favicon-96x96.png` : Standar wajib Google Search (kelipatan 48px).
- `public/favicon-192x192.png` & `favicon-512x512.png` : Ikon PWA & Shortcut Android.
- `public/apple-touch-icon.png` (180x180) : Ikon Home Screen iOS Safari.
- `public/logo.png` (512x512) : Logo resmi berlatar transparan untuk Google Knowledge Graph (Schema.org).
- `public/favicon.ico` : File multi-layer ICO (16, 32, 48, 64px).
- `public/sitemap.xml` & `public/robots.txt` : Terkonfigurasi rapi untuk Googlebot.
- **Cache-Busting:** Seluruh tautan ikon di semua file HTML/Astro menggunakan parameter `?v=3` untuk mencegah cache browser lama.

### ⚠️ Catatan Penting Mengenai Google Search:
- Jika di pencarian Google (`google.com`) judul atau logo masih menampilkan data lama Astro, ini wajar karena Googlebot memperbarui cache indeksnya setiap **24–48 jam**.
- **Cara mempercepat:** Buka [Google Search Console](https://search.google.com/search-console) -> Masukkan `https://kamawak.id/` dan `https://kamawak.id/login` -> Klik **"Minta Pengindeksan"** (*Request Indexing*).

---

## 6. KONFIGURASI MOBILE ANDROID (CAPACITOR)
- **Path Android:** `/Volumes/Abay Doc/kamawak-astro/android`
- **Package ID:** `id.kamawak.app`
- **Ikon Launcher (Adaptive Icons):**
  - `android/app/src/main/res/values/ic_launcher_background.xml`: Warna background telah diset ke oranye resmi `#FF5E1F` (sebelumnya `#FFFFFF`).
  - `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png`: Monogram "K" putih diposisikan presisi di safe zone 66% tanpa kotak putih.
  - `android/app/src/main/res/mipmap-*/ic_launcher.png`: Full squircle oranye untuk launcher klasik.
  - Menghapus artefak bawaan `drawable-v24/ic_launcher_foreground.xml` agar tidak menimpa logo di Android API 24+.

---

## 7. CARA MENJALANKAN & MEN-DEPLOY PROYEK
```bash
# 1. Pindah ke direktori proyek
cd "/Volumes/Abay Doc/kamawak-astro"

# 2. Menjalankan server lokal pengembangan
npm run dev
# Buka http://localhost:4321 di browser

# 3. Melakukan build produksi
npm run build

# 4. Sinkronisasi aset ke aplikasi Android Capacitor
npx cap sync android

# 5. Push ke GitHub (Otomatis memicu deploy Cloudflare Pages & Build APK jika ada tag)
git add .
git commit -m "feat: deskripsi perubahan"
git push origin main
```

---

## 8. ROADMAP & TUGAS PENGEMBANGAN SELANJUTNYA
1. **Verifikasi Indeksasi Google:** Memantau Google Search Console hingga snippet pencarian menampilkan judul baru dan logo Monogram K.
2. **Payment Gateway (Opsional):** Integrasi payment gateway otomatis (Midtrans / Xendit / Tripay) jika ingin menyediakan pembayaran otomatis selain transfer manual / direct WhatsApp ke pemilik.
3. **PWA & Offline Mode:** Menambahkan service worker `sw.js` dan `manifest.json` agar website dapat di-install sebagai Web App di iPhone & Android tanpa lewat Play Store.
4. **Publish APK:** Mengunggah file APK hasil build GitHub Actions ke Google Play Console atau menyediakan tombol "Download APK" langsung di landing page.
