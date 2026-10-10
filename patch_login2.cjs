const fs = require('fs');
const path = require('path');
const dest = '/Users/bayuichsanalgani/Documents/kamawak-astro/src/pages/login.astro';

let content = fs.readFileSync(dest, 'utf8');

// The block starts at `google.script.run.withFailureHandler` and ends at `}).verifikasiLogin(identitas, pass);`
const startStr = 'google.script.run.withFailureHandler';
const endStr = '}).verifikasiLogin(identitas, pass);';

const startIndex = content.indexOf(startStr);
const endIndex = content.indexOf(endStr) + endStr.length;

if (startIndex !== -1 && endIndex !== -1) {
  const newLoginBlock = `      // MENGGUNAKAN SUPABASE
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('nama', identitas)
        .eq('password', pass)
        .single();
        
      loader.style.display = "none"; btn.style.display = "block";
      
      if (error || !data) {
          txtBox.innerText = "Kredensial tidak valid atau tidak ditemukan."; msgBox.className = "msg-box msg-error"; msgBox.style.display = "block";
      } else {
          localStorage.setItem("kamawak_user", data.nama); 
          localStorage.setItem("kamawak_role", data.role);
          
          let roleStr = data.role.toLowerCase();
          let halamanTujuan = "";
          
          if (roleStr.includes("admin")) {
            halamanTujuan = "/admin";
          } else if (roleStr.includes("owner") || roleStr.includes("mitra")) {
            halamanTujuan = "/owner";
          } else {
            halamanTujuan = "/profil";
          }
          
          let urlAkhir = halamanTujuan + "?u=" + encodeURIComponent(data.nama) + "&r=" + encodeURIComponent(data.role);
          window.top.location.href = urlAkhir;
      }`;
      
  content = content.substring(0, startIndex) + newLoginBlock + content.substring(endIndex);
  fs.writeFileSync(dest, content);
  console.log('Patched login.astro successfully!');
} else {
  console.log('Could not find the block to replace.');
}
