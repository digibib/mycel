$(document).ready(function () {

  // ** connect to mycel websocket server

  //var ws = new WebSocket("ws://localhost:9001/subscribe/branches");
  var ws = new WebSocket("ws://10.172.2.100:9001/subscribe/branches");


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
    var nr = parseInt($tr.find('span.logged_on').html());
    switch (data.status) {
      case "ping":
      	// do nothing
        break;
      case "logged-on":
        $tr.find('img.inactive:first').removeClass("inactive").addClass("active").attr("src", "/img/pc_green.png");
        $tr.find('span.logged_on').html(nr -1);
        break;
      case "logged-off":
        $tr.find('img.active:last').removeClass("active").addClass("inactive").attr("src", "/img/pc_black.png");
        $tr.find('span.logged_on').html(nr + 1);
        break;
      default:
    }
  }


}); // end of document(ready)
