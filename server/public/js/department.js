// TODO change all # duplicates to .class
// TODO split this into common.js, department.js and branch.js when done

$(document).ready(function () {

  // ** global vars
  var dept_id = $('input#level_id').val();
  var backup = new Object();
  backup.homepage = $('input#homepage').val();
  backup.al = $('input#age_lower').val();
  backup.ah = $('input#age_higher').val();

  // ** connect to mycel websocket server

  var ws = new WebSocket("ws://localhost:9001/subscribe/departments/"+dept_id);

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
    var msg = "";
    var $tr =  $("tr#"+data.client.id);
    switch (data.status) {
      case "ping":
        if ( $tr.find('.td-minutes').html() != "") {
          // to counter late ping with minutes update
          $tr.find('input.minutes').val(data.user.minutes);
          if (data.user.type === "B" ) {
              var adjust = parseInt($('#dm_'+data.client.dept_id).val());
              $tr.find('.td-minutes').html(data.user.minutes+adjust);
          } else {
              $tr.find('.td-minutes').html(data.user.minutes);
          }
        }
        break;
      case "logged-on":
        $tr.find('img').attr("src", "/img/pc_green.png");
        $tr.find('.toggle').removeClass('hidden');
        $tr.find('input.user_id').val(data.user.id);
        $tr.find('.td-user').html(data.user.name);
        $tr.find('input.minutes').val(data.user.minutes);
        $tr.find('.td-minutes').html(data.user.minutes);
        msg = "logget på";
        break;
      case "logged-off":
        $tr.find('img').attr("src", "/img/pc_black.png");
        $tr.find('.toggle').addClass('hidden');
        $tr.find('.td-user').html("");
        $tr.find('.td-minutes').html("");
        msg = "logget av";
        break;
      default:
    }
    // display message
    $("tr#"+data.client.id).find('span.info').html(msg).show().fadeOut(5000);
  }


  // ** set input masks **

  $('input#user_minutes').setMask('999');
  $('table.clients').find('input.nr.required').setMask('999');

  // ** global functions and handles **

  $(':input').focus(function () {
    if ($(this).hasClass('inputmissing')) {
      $(this).removeClass('inputmissing');
    }
  });

   // ** handle client-options events **

  $("img.pc").on("click", function() {
    var client_id = $(this).parents("tr").attr('id');
    var $s = $("tr.clientoptions.client_"+client_id);
    $s.toggle();
    if (($s).is(':visible')) {
      $('tr.options_open').removeClass("options_open").hide();
      $s.addClass("options_open");
    } else {
      $s.removeClass("options_open");
    }
  });


  $('button.clientsave').on('click', function () {
    var $s = $('tr.options_open');
    var shortbool = false;
    if ($s.find('input.shorttimemachine').is(':checked')) {
      shortbool = true;
    }

    var client_id = $s.find('input.client_id').val();

    var request = $.ajax({
      url: '/api/clients/'+client_id,
      type: 'PUT',
      data: {
            screen_resolution_id: $s.find('.client_screen_res option:selected').val(),
            shorttime: shortbool
            },
      dataType: "json"
    });

    request.done(function(msg) {
      $('tr#'+client_id).find('span.info').html('OK! Lagret.').show().fadeOut(5000);
      $s.removeClass("options_open");
      $s.toggle();
    })

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('tr#'+client_id).find('span.error')
        .html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  $('button.clientcancel').on('click', function () {
    $s = $('tr.options_open');
    $s.removeClass("options_open");
    $s.toggle();
  });

  // ** handle client-user events **

  $('button.throw-out').on('click', function () {
    result = confirm("Brukeren vil bli logget av uten forvarsel.\nEr du sikker?");
    if (result) {
      $(this).parents('tr').find('span.info').html("Ikke ennå!").show().fadeOut(5000);
      }
  });

  // ** Handle adjust user minutes
  $('button.users.add_time').on('click', function () {

    var $i = $(this).siblings('input.nr.required')
    if (parseInt($i.val()) == 0) {
      $i.val('');
      return;
    }
    if ($i.val() =='' ) {
      $i.addClass('inputmissing');
      return;
    }

    var $tr = $(this).parents('tr');
    var user_id = $tr.find('input.user_id').val();
    var $min = $tr.find('input.users.minutes');
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
      $tr.find('td.td-minutes').html(data.user.minutes);
      $i.val('');
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
        $tr.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
     });

  });


});

