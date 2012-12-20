$(document).ready(function () {
  // ** connect to mycel websocket server
  var ws = new WebSocket("ws://localhost:9001/subscribe/users");

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

    $tr = $("tr#"+data.user.id);

    switch (data.status) {
      case "ping":
        $tr.find('.td-minutes').html(data.user.minutes);
        break;
      case "logged-on":
        $tr.remove();

        var trstr = "<tr id='"+data.user.id +"'><td class='td-usertype'>" +data.user.type +"</td>"
        trstr += "<td class='td-username'>"+data.user.name+"</td><td class='td-minutes' style='width:40px'>"
        trstr += data.user.minutes+"</td><td class='td-adjust'><div style='width:80px'>"
        trstr += "<input class='users minutes' type='hidden' value='"+data.user.minutes+"'>"
        trstr += "<input class='nr required' type='text'><button class='users add_time' type='button'>+</button></div>"
        trstr += "</td><td class='td-branchdept'><a href='/"+data.client.branch+"'>"+data.client.branch+"</a>/"
        trstr += "<a href='/"+data.client.branch+"/"+data.client.department+"'>"+data.client.department+"</a></td>"
        trstr += "<td class='td-clientname'>"+data.client.name+"</td><td class='td-throwout'>"
        trstr += "<button class='users throw-out' type='button'>Kast ut!</button></td></tr>"

        if ( $('input.allowed_departments[value='+data.client.dept_id+']').length != 0 ) {
          $('table.active').
            find('tbody').append(trstr).
            find('input.nr').setMask('999').
            end().
            trigger("update", [true]);
        break;
        }
      case "logged-off":
        $tr.remove();

        if (data.user.type != "A") {
          $trcopy = $("table.inactive tr:last").clone();
          $trcopy.attr("id", data.user.id);
          $trcopy.find('.td-usertype').html(data.user.type);
          $trcopy.find('.td-username').html(data.user.name);
          $trcopy.find('.td-minutes').html(data.user.minutes);
          $trcopy.find('input.users.minutes').val(data.user.minutes);
          $trcopy.find('input.nr').setMask('999');

          $('table.inactive').
            find('tbody').append($trcopy).
            end().
            trigger("update", [true]);
        }
        break;
    }

  }

  // ** global functions and handles **

  $('.main').on('focus', ':input', function () {
    if ($(this).hasClass('inputmissing')) {
      $(this).removeClass('inputmissing');
    }
  });


  // ** set input masks **

  $('input.nr').setMask('999');


  // ** tablesorter setup **
  $("#activeusers").tablesorter({
    theme : 'blue',
    headers: {
         5: { sorter: false }
       },
    sortList: [[4,0],[1,0]],
    widthFixed : true,
    widgets: ["filter"],
    widgetOptions : {    }
  });

  $("#inactiveusers").tablesorter({
    theme : 'blue',
    headers: {
         3: { sorter: false },
         4: { sorter: false}
       },
    sortList: [[1,0]],
    widthFixed : true,
    widgets: ["filter"],
    widgetOptions : {    }
  });

  // Hide input-filters on filter-disabled columns
  // there is no options for this in the plugin
  $("input.tablesorter-filter").slice(-3).hide();
  $("input.tablesorter-filter").slice(2,4).hide();
  $("input.tablesorter-filter").slice(5,7).hide();


  // ** Handle delete user

  $('table.users.inactive').on('click', 'button.users.delete',  function () {
    var user_id = $(this).parents('tr').attr('id');

    var request = $.ajax({
      url: "/api/users/"+user_id,
      type: "DELETE"
    });

    request.done(function(msg) {
      $('tr#'+user_id).remove();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
        // TODO where to display error message?
        //alert(jqXHR.responseText);
    });
  });

  // ** Handle adjust user minutes
  $('table.users').on('click', 'button.users.add_time', function () {

    var $i = $(this).siblings('input.nr.required');
    if (parseInt($i.val()) == 0) {
      $i.val('');
      return;
    }
    if ($i.val() =='' ) {
      $i.addClass('inputmissing');
      return;
    }

    var user_id = $(this).parents('tr').attr('id');
    var $min = $('tr#'+user_id).find('input.users.minutes');
    var user_minutes = $min.val();

    var request = $.ajax({
      url: '/api/users/'+user_id,
      type: "PUT",
      data: {
            minutes: parseInt(user_minutes)+parseInt($i.val())
            },
      dataType: "json"
    });

    request.done(function(data) {
      $min.val(data.user.minutes); // update hidden input
      $('tr#'+user_id).find('td.td-minutes').html(data.user.minutes);
      $i.val('');
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
         // TODO where to display error message?
         //alert(jqXHR.responseText);
     });

  });

  // ** handle add-guest-user events **

  $("button#adduser").on("click", function() {
    $('table.userform').toggle();
  });
  $("button#usercancel").on("click", function() {
    $('table.userform').hide();
  });

  $('button#usersave').on('click', function () {
    var missing = 0;
    $('#add_user_form').find('input.required').each(function() {
      if ($(this).val() == '' ) {
        $(this).addClass('inputmissing');
        missing = 1;
      }
    });

    if (missing) { return; }

    var request = $.ajax({
      url: '/api/users',
      type: 'POST',
      data: {
             username: $('input#username').val(),
             password: $('input#user_password').val(),
             age: $('select#user_age').val(),
             minutes: $('input#user_minutes').val(),
             },
      dataType: "json"
      });

    request.done(function(data) {
      $('#user_saved_info').html('OK! Bruker "' + data.user.username + '" oprettet.')
        .show().fadeOut(5000);
        // Show in inactive users table
        $('#add_user_form')[0].reset();
        $('table.userform').hide();
        var tr = '<tr id="' + data.user.id + '"><td>G</td><td>'+data.user.username;
        tr +=  '</td><td class="td-minutes" style="width:40px">' + data.user.minutes;
        tr += '</td><td><input class="users minutes" type="hidden" value="'+data.user.minutes;
        tr += '"><input class="nr required" type="text"><button class="users add_time" type="button">';
        tr += '+</button></td><td><button class="users delete" type="button">Slett</button></td></tr>';
        $('table.users.inactive').append(tr);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('td#user_form_response').find('span.error')
        .html("Brukeren finnes allerede! Velg et annet brukernavn.").show().fadeOut(5000);
    })
  });

});
