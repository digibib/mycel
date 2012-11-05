$(document).ready(function () {

  // ** connect to mycel websocket server

  var ws = new WebSocket("ws://localhost:9001/subscribe/branches");

  // handle ws events

  ws.onopen = function() {
    //var message = {action: "subscribe", department: dept};
    //ws.send(JSON.stringify(message));
  }

  ws.onclose = function() {
    // close
  }

  ws.onmessage = function(evt) {
    // message
    console.log(evt.data);
    data = JSON && JSON.parse(evt.data) || $.parseJSON(evt.data);
    var $tr =  $("tr#"+data.client.dept_id);
    switch (data.status) {
      case "ping":
      	// do nothing
        break;
      case "logged-on":
        $tr.find('img.inactive:first').removeClass("inactive").addClass("active").attr("src", "/img/pc_green.png");
        break;
      case "logged-off":
        $tr.find('img.active:first').removeClass("active").addClass("inactive").attr("src", "/img/pc_black.png");
        break;
      default:
    }
  }


}); // end of document(ready)