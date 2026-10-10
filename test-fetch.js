const API_URL = "https://script.google.com/macros/s/AKfycbx-Pq4wVKrDIpI0mND2sCE7OnjplvdUkvPM9dhXQ558uLLN1duBy92EsUETgSCd_9hn/exec";
async function run() {
  try {
    const res = await fetch(API_URL + "?api=true&action=getRekapitulasiAdminGlobal", {
        redirect: 'follow'
    });
    const text = await res.text();
    console.log("Success:", text);
  } catch (e) {
    console.error("Error:", e);
  }
}
run();
