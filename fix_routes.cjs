const fs = require('fs');
const path = require('path');
const destDir = '/Users/bayuichsanalgani/Documents/kamawak-astro/src/pages';
const files = ['index.astro', 'admin.astro', 'login.astro', 'profil.astro', 'owner.astro', 'pdp.astro'];

for (const file of files) {
  const filePath = path.join(destDir, file);
  let content = fs.readFileSync(filePath, 'utf8');

  // Fix BASE_URL concatenation and "?page=..."
  // `BASE_URL + "?page=index"` -> `"/"`
  // "?page=index" -> "/"
  content = content.replace(/\?page=index/g, '/');
  
  // `?page=admin` -> `/admin`
  content = content.replace(/\?page=admin/g, '/admin');
  
  // `?page=owner` -> `/owner`
  content = content.replace(/\?page=owner/g, '/owner');
  
  // `?page=profil` -> `/profil`
  content = content.replace(/\?page=profil/g, '/profil');
  
  // `?page=login` -> `/login`
  content = content.replace(/\?page=login/g, '/login');
  
  // `?page=pdp&` -> `/pdp?`
  content = content.replace(/\?page=pdp&/g, '/pdp?');
  
  // `?page=pdp` -> `/pdp`
  content = content.replace(/\?page=pdp/g, '/pdp');
  
  // `halamanTujuan = "?page=admin"` in login.astro
  // is now `halamanTujuan = "/admin"` which is fine
  
  // What about `"?page=" + target`?
  content = content.replace(/\?page=" \+ target/g, '/" + target + "?_"');
  // if target is "admin", url becomes BASE_URL + "/" + "admin" + "?_&u="... 
  // Wait, let's just make BASE_URL = "" and let it be relative? No, it should be absolute from root.
  // Actually, we can just replace `let urlAkhir = BASE_URL + halamanTujuan + "&u="` with `let urlAkhir = halamanTujuan + "?u="`
  
  fs.writeFileSync(filePath, content);
}
console.log("Routes fixed");
