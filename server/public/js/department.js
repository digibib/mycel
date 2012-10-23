// TODO change all # duplicates to .class
// TODO split this into common.js, department.js and branch.js when done
// read dept_id here at top

// ** conveniece functions **

$.fn.exists = function () {
  return this.length != 0;
}

$(document).ready(function () {
  // ** global vars

  var dept_id = $('input#department_id').val();
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
          $tr.find('.td-minutes').html(data.user.minutes);
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
  $('input#age_lower').setMask('99');
  $('input#age_higher').setMask('99');
  $('input#minutes_limit').setMask('999');
  $('table.clients').find('input.nr.required').setMask('999');
  $('input#minutes_before_closing').setMask('99');

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

  // ** handle opening-hours events **

  $(':input.chk').change(function () {
    if ($(this).attr("checked"))
    {
      var id = $(this).attr("id").slice(0, -6);
      $("#"+id+"opens").attr("disabled", "disabled").removeClass("inputmissing");
      $("#"+id+"closes").attr("disabled", "disabled").removeClass("inputmissing");
    } else {
      var id = $(this).attr("id").slice(0, -6);
      $("#"+id+"opens").removeAttr("disabled");
      $("#"+id+"closes").removeAttr("disabled");
    }
  });

  $(':input.hour').setMask('29:59').keypress(function() {
    var currentMask = $(this).data('mask').mask;
    var newMask = $(this).val().match(/^2.*/) ? "23:59" : "29:59";
    if (newMask != currentMask) {
      $(this).setMask(newMask);
    }
  });

  $('button#hoursclear').on('click', function () {
    backup.ohcopy = $('#change_hours_form').clone();
    $('#change_hours_form')[0].reset();
    $('input#minutes_before_closing').val('')
    $(':input.hour').val('').removeClass("inputmissing");
    $(':input.hour').removeAttr("disabled");
    $(':input.chk').removeAttr('checked');
  });

  $('button#hourssave').on('click', function() {
    var missing = 0;
    $('input.hour.required:not(:disabled)').each(function () {
      if ($(this).val() == '' ) {
        $(this).addClass('inputmissing');
        missing += 1;
      }
    });

    // return if one or more (but not all 14) input fields are missing
    if (missing && (missing != 14 )) { return; }

    $(':input.hour').removeClass("inputmissing");

    // remove opening_hours on department, and inherit from branch
    // if all fields are blank

    // TODO refactor into one request, create data on beforehand
    if (missing == 14) {
      var request = $.ajax({
        url: '/api/departments/'+dept_id,
        type: 'PUT',
        cache: false,
        data: {
              opening_hours: "inherit"
              },
        dataType: "json"
      });
    } else {
      var request = $.ajax({
        url: '/api/departments/'+dept_id,
        type: 'PUT',
        cache: false,
        data: {
              opening_hours: {
              monday_opens: $('input#monday_opens').val(),
              monday_closes: $('input#monday_closes').val(),
              tuesday_opens: $('input#tuesday_opens').val(),
              tuesday_closes: $('input#tuesday_closes').val(),
              wednsday_opens: $('input#wednsday_opens').val(),
              wednsday_closes: $('input#wednsday_closes').val(),
              thursday_opens: $('input#thursday_opens').val(),
              thursday_closes: $('input#thursday_closes').val(),
              friday_opens: $('input#friday_opens').val(),
              friday_closes: $('input#friday_closes').val(),
              saturday_opens: $('input#saturday_opens').val(),
              saturday_closes: $('input#saturday_closes').val(),
              sunday_opens: $('input#sunday_opens').val(),
              sunday_closes: $('input#sunday_closes').val(),
              monday_closed: $('input#monday_closed').is(':checked'),
              tuesday_closed: $('input#tuesday_closed').is(':checked'),
              wednsday_closed: $('input#wednsday_closed').is(':checked'),
              thursday_closed: $('input#thursday_closed').is(':checked'),
              friday_closed: $('input#friday_closed').is(':checked'),
              saturday_closed: $('input#saturday_closed').is(':checked'),
              sunday_closed: $('input#sunday_closed').is(':checked'),
              minutes_before_closing: $('input#minutes_before_closing').val()
              }},
        dataType: "json"
      });
    }


    request.done(function(data) {
      $('span#hours_error').hide();
      if (data.department.options.opening_hours) {
        $('span#hours_info').html("OK! Lagret.").show().fadeOut(5000);
        $('#change_hours_form').find('span.inherited').hide();
      } else {
        $('span#hours_info').html("OK! Arver instillinger").show().fadeOut(5000);
        $('#change_hours_form').find('span.inherited').show();
        $.each(data.department.options_inherited.opening_hours, function(k, v) {
          if (v == true) {
            $('input#'+k).attr('checked', true);
            $('#'+k.slice(0,-6)+'opens').attr("disabled", "disabled");
            $('#'+k.slice(0,-6)+'closes').attr("disabled", "disabled");
          } else {
            $('input#'+k).val(v); }
        });
      }
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#hours_info').hide();
      console.log(jqXHR.responseText);
      if (backup.ohcopy) {
        $('#change_hours_form').replaceWith(backup.ohcopy);
      }
      backup.ohcopy = null;
      $('span#hours_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // ** handle age-limit events
  $('button#agesave').on('click', function () {
    var lower = $('input#age_lower').val();
    var higher = $('input#age_higher').val();
    if ((lower == "") && (higher == "")) {
      var age_data = { age_limit_lower: "inherit", age_limit_higher: "inherit" };
    } else {
      var age_data = { age_limit_lower: lower, age_limit_higher: higher};
    }

    request = $.ajax({
      url: "/api/departments/"+dept_id,
      type: "PUT",
      cache: false,
      data: age_data,
      dataType: "json"
    });

    request.done(function(data) {
      if (data.department.options.age_limit_higher || data.department.options.age_limit_lower) {
        var al = data.department.options.age_limit_lower ? data.department.options.age_limit_lower : data.department.options_inherited.age_limit_lower;
        var ah = data.department.options.age_limit_higher ? data.department.options.age_limit_higher : data.department.options_inherited.age_limit_higher;;


        $('input#age_lower').val(al);
        $('input#age_higher').val(ah);
        $('span#age_inherited').hide();
        var msg = "OK! Lagret.";
      } else {
        $('input#age_lower').val(data.department.options_inherited.age_limit_lower);
        $('input#age_higher').val(data.department.options_inherited.age_limit_higher);
        $('span#age_inherited').show();
        var msg = "OK! Arver instillinger";
      }
      $('span#age_info').html(msg).show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#age_error').html(jqXHR.responseText).show().fadeOut(5000);
      $('#age_lower').val(backup.al);
      $('#age_higher').val(backup.ah);
    });

  });

  // ** handle timie-limit events

  $('input#time_limit_no_limit').change(function () {
    if($(this).attr("checked"))
    {
      $('input#time_limit').attr("disabled", "disabled");
    } else {
      $('input#time_limit').removeAttr("disabled");
    }
  });

  $('button#time_save').on('click', function () {
    var time = $('input#time_limit').val();
    if (time == "") { hp = "inherit"; }

    request = $.ajax({
      url: "/api/departments/"+dept_id,
      type: "PUT",
      cache: false,
      data: {
            time_limit: time,
            time_limit_no_limit: $('input#time_limit_no_limit').is(':checked')
            },
      dataType: "json"
    });

    request.done(function(data) {
      if (data.department.options.time_limit || data.department.options.time_limit_no_limit) {
        $('span#time_inherited').hide();
        var msg = "OK! Lagret.";
      } else {
        $('span#time_inherited').show();
        $('input#time_limit').val(data.department.tions_opinherited.time_limit);
        var msg = "OK! Arver instillinger";
      }
      $('span#time_info').html(msg).show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#time_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });


  // ** handle save homepage
  $('button#homepagesave').on('click', function () {
    var hp = $('input#homepage').val();
    if (hp == "") { hp = "inherit"; }

    request = $.ajax({
      url: "/api/departments/"+dept_id,
      type: "PUT",
      cache: false,
      data: { homepage: hp },
      dataType: "json"
    });

    request.done(function(data) {
      if (data.department.options.homepage) {
        $('span#homepage_inherited').hide();
        var msg = "OK! Lagret.";
      } else {
        $('span#homepage_inherited').show();
        $('input#homepage').val(data.department.options_inherited.homepage);
        var msg = "OK! Arver instillinger";
      }
      $('span#homepage_info').html(msg).show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#homepage_error').html(jqXHR.responseText).show().fadeOut(5000);
      $('#homepage').val(backup.homepage);
    });
  });

  // ** handle save printer
  $('button#printersave').on('click', function () {

    request = $.ajax({
      url: "/api/departments/"+dept_id,
      type: "PUT",
      cache: false,
      data: { printeraddr: $('input#printer').val() },
      dataType: "json"
    });

    request.done(function(data) {
      $('span#printer_info').html("OK! Lagret.").show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#printer_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });


});

