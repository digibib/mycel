$(document).ready(function () {

  // check if browser has support for webscockets
  if (!("WebSocket" in window)) {
     var msg =  'Nettleseren din støtter ikke websockets, og systemet derfor ikke kunne oppdateres i sanntid.\nDu vil allikevel kunne administrere klientene, men for best funksjonalitet bør du bruke en nyere nettleser.';
     $("#debug").append("<pre>" + msg + "</pre>");
     return;
  };


}); // end of document(ready)