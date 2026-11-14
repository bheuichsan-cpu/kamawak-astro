import { createClient } from '@supabase/supabase-js';

// Kunci anon dibaca dari variabel PUBLIC_ (memang publik). Jangan menaruh
// service_role atau kunci rahasia lain di sini atau di variabel PUBLIC_.
const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

// Sesi Supabase Auth disimpan di peramban (persistSession) dan diperbarui otomatis.
// Identitas/peran yang dipercaya database berasal dari token sesi ini (auth.uid()),
// BUKAN dari localStorage.
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storageKey: 'kamawak-auth'
  }
});

// Cache tampilan saja (nama/peran untuk navbar). Bukan dasar izin.
const KUNCI_LOKAL = ['kamawak_id', 'kamawak_user', 'kamawak_role'];

export function simpanSesiLokal(profil) {
  try {
    localStorage.setItem('kamawak_id', profil.id);
    localStorage.setItem('kamawak_user', profil.nama || profil.email || '');
    localStorage.setItem('kamawak_role', profil.role || 'Wisatawan');
  } catch (e) {}
}

export function bersihkanSesiLokal() {
  try { KUNCI_LOKAL.forEach((k) => localStorage.removeItem(k)); } catch (e) {}
}

// Profil pengguna yang sedang login (baris profiles milik sendiri, dijaga RLS), atau null.
export async function ambilProfilSaya() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return null;
  const { data, error } = await supabase
    .from('profiles')
    .select('id, nama, username, email, wa, role, status_langganan, nama_usaha')
    .eq('id', session.user.id)
    .single();
  if (error || !data) return null;
  return data;
}

// Keluar: akhiri sesi di server lalu bersihkan cache tampilan.
export async function keluarAkun() {
  try { await supabase.auth.signOut(); } catch (e) {}
  bersihkanSesiLokal();
}

if (typeof window !== 'undefined') {
  // Sesi habis/ditutup di tempat lain: bersihkan cache tampilan agar navbar tidak menampilkan akun palsu.
  supabase.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT') bersihkanSesiLokal();
  });
  // Pengguna lama yang masih punya kamawak_user dari sistem lama tapi tanpa sesi Auth.
  supabase.auth.getSession().then(({ data }) => {
    if (!data || !data.session) bersihkanSesiLokal();
  }).catch(() => {});
}
