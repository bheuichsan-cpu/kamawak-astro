import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.PUBLIC_SUPABASE_ANON_KEY;
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function test() {
  const { data, error } = await supabase.from('users').insert([
    { nama: 'admin', password: 'admin123', role: 'Admin' }
  ]).select();
  console.log("Insert Data:", data, "Error:", error);
}
test();
