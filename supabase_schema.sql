-- Skema Database Kamawak OTA (Supabase)

-- 1. Tabel Users
CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    nama text UNIQUE NOT NULL,
    password text NOT NULL,
    role text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Tabel Wisata (Katalog)
CREATE TABLE public.wisata (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    nama text NOT NULL,
    lokasi text,
    kategori text,
    harga numeric,
    foto text,
    wa text,
    owner text,
    status text DEFAULT 'Aktif',
    deskripsi text,
    fasilitas text,
    varian text,
    tags text,
    itinerary text,
    harga_coret numeric,
    durasi text,
    maps text,
    ig text,
    tiktok text,
    fb text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- JALANKAN DI SUPABASE SQL EDITOR JIKA TABEL SUDAH DIBUAT SEBELUMNYA:
-- ALTER TABLE public.wisata 
-- ADD COLUMN IF NOT EXISTS deskripsi text,
-- ADD COLUMN IF NOT EXISTS fasilitas text,
-- ADD COLUMN IF NOT EXISTS varian text,
-- ADD COLUMN IF NOT EXISTS tags text,
-- ADD COLUMN IF NOT EXISTS itinerary text,
-- ADD COLUMN IF NOT EXISTS harga_coret numeric,
-- ADD COLUMN IF NOT EXISTS durasi text,
-- ADD COLUMN IF NOT EXISTS maps text,
-- ADD COLUMN IF NOT EXISTS ig text,
-- ADD COLUMN IF NOT EXISTS tiktok text,
-- ADD COLUMN IF NOT EXISTS fb text;

-- 3. Tabel Leads (Klik & Metrik)
CREATE TABLE public.leads (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    wisata_id uuid REFERENCES public.wisata(id),
    platform text NOT NULL, -- 'wa', 'ig', 'fb', 'tiktok'
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Tabel Transaksi / Penarikan (Saldo)
CREATE TABLE public.transaksi (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_nama text NOT NULL,
    nominal numeric NOT NULL,
    rekening text,
    status text DEFAULT 'Pending', -- 'Pending', 'Selesai'
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- INSERT DATA AWAL (Admin & Wisatawan)
INSERT INTO public.users (nama, password, role) VALUES 
('admin1', 'admin123', 'Admin'),
('bayu', 'bayu123', 'Wisatawan');


-- 5. Tabel Buku Kas (Laba/Rugi)
CREATE TABLE public.buku_kas (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    jenis text NOT NULL,      -- 'Pemasukan' atau 'Pengeluaran'
    kategori text NOT NULL,   -- 'Langganan Mitra', 'Komisi OTA', dll
    keterangan text,
    nominal numeric NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- JANGAN LUPA: MATIKAN RLS (Row Level Security) untuk semua tabel agar admin/client bisa membaca dan menulis data
-- ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.wisata DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.leads DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.transaksi DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.buku_kas DISABLE ROW LEVEL SECURITY;
