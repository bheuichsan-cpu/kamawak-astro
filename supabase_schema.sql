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
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

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

