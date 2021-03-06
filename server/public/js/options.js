// TODO change all # duplicates to .class
// TODO split this into common.js, department.js and branch.js when done
// read branch_id here at top

$(document).ready(function () {

  // ** global vars
  var level_id = $('input#level_id').val();
  var level_type = $('input#level_type').val();
  switch (level_type) {
    case "Branch":
      var level_url = "branches";
      break;
    case "Department":
      var level_url = "departments";
      break
    case "Organization":
      var level_url = "organization";
      break;
  }

  var backup = new Object();
  backup.homepage = $('input#homepage').val();
  backup.al = $('input#age_lower').val();
  backup.ah = $('input#age_higher').val();

  // ** set input masks **

  $('input#user_minutes').setMask('999');
  $('input#age_lower').setMask('999');
  $('input#age_higher').setMask('999');
  $('input#minutes_limit').setMask('999');
  $('input#minutes_before_closing').setMask('99');

  // ** global functions and handles **

  $(':input').focus(function () {
    if ($(this).hasClass('inputmissing')) {
      $(this).removeClass('inputmissing');
    }
  });

  // ** options tabs handling **
  $('.pane').hide();
  $('.pane:first').addClass('active').show();

  $('.tabs li').on('click', function() {
    $('.tabs li.active').removeClass('active');
    $(this).addClass('active');
    var idx = $(this).index();
    $('.pane').hide();
    $('.pane:eq('+idx+')').show();
  });


  // ** handle opening-hours events **

  $(':input.chk').change(function () {
    if($(this).attr("checked"))
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
    $(':input.nr').removeClass("inputmissing");
  });

  $('button#hourssave').on('click', function() {
    var missing = 0;
    $('#oh_table').find('input.required:not(:disabled)').each(function () {
      if ($(this).val() == '' ) {
        $(this).addClass('inputmissing');
        missing += 1;
      }
    });

    // return if one or more (but not all 14) input fields are missing
    if (missing && (missing != 15 )) { return; }

    $(':input.nr').removeClass("inputmissing");
    $(':input.hour').removeClass("inputmissing");

    // remove opening_hours on branch, and inherit from branch
    // if all fields are blank

    // TODO refactor into one request, create data on beforehand
    if (missing == 15) {
      var request = $.ajax({
        url: '/api/' + level_url + '/' + level_id,
        type: 'PUT',
        cache: false,
        data: {
              opening_hours: "inherit"
              },
        dataType: "json"
      });
    } else {
      var request = $.ajax({
        url: '/api/' + level_url + '/' + level_id,
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
      var level = data.organization || data.branch || data.department;
      $('span#hours_error').hide();
      if (level.options.opening_hours) {
        $('span#hours_info').html("OK! Lagret.").show().fadeOut(5000);
        $('#change_hours_form').find('span.inherited').hide();
      } else {
        $('span#hours_info').html("OK! Arver instillinger").show().fadeOut(5000);
        $('#change_hours_form').find('span.inherited').show();
        $.each(level.options_inherited.opening_hours, function(k, v) {
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
      url: '/api/' + level_url + '/' + level_id,
      type: "PUT",
      cache: false,
      data: age_data,
      dataType: "json"
    });

    request.done(function(data) {
      var level = data.organization || data.branch || data.department;
      if (level.options.age_limit_higher || level.options.age_limit_lower) {
        var al = level.options.age_limit_lower ? level.options.age_limit_lower : level.options_inherited.age_limit_lower;
        var ah = level.options.age_limit_higher ? level.options.age_limit_higher : level.options_inherited.age_limit_higher;;

        $('input#age_lower').val(al);
        $('input#age_higher').val(ah);
        $('span#age_inherited').hide();
        var msg = "OK! Lagret.";
      } else {
        $('input#age_lower').val(level.options_inherited.age_limit_lower);
        $('input#age_higher').val(level.options_inherited.age_limit_higher);
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

  // ** handle time-limit events

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
      url: '/api/' + level_url + '/' + level_id,
      type: "PUT",
      cache: false,
      data: {
            time_limit: time,
            time_limit_no_limit: $('input#time_limit_no_limit').is(':checked')
            },
      dataType: "json"
    });

    request.done(function(data) {
      var level = data.organization || data.branch || data.department;
      if (level.options.time_limit || level.options.time_limit_no_limit) {
        $('span#time_inherited').hide();
        var msg = "OK! Lagret.";
      } else {
        $('span#time_inherited').show();
        $('input#time_limit').val(level.options_inherited.time_limit);
        var msg = "OK! Arver instillinger";
      }
      $('span#time_info').html(msg).show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#time_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // ** handle shorttime-limit events

  $('button#shorttime_save').on('click', function () {
    var time = $('input#shorttime_limit').val();
    if (time == "") { hp = "inherit"; }

    request = $.ajax({
      url: '/api/' + level_url + '/' + level_id,
      type: "PUT",
      cache: false,
      data: {
            shorttime_limit: time,
            },
      dataType: "json"
    });

    request.done(function(data) {
      var level = data.organization || data.branch || data.department;
      if (level.options.shorttime_limit) {
        $('span#shorttime_inherited').hide();
        var msg = "OK! Lagret.";
      } else {
        $('span#shorttime_inherited').show();
        $('input#shorttime_limit').val(level.options_inherited.shorttime_limit);
        var msg = "OK! Arver instillinger";
      }
      $('span#shorttime_info').html(msg).show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#shorttime_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // ** handle save homepage
  $('button#homepagesave').on('click', function () {
    var hp = $('input#homepage').val();
    if (hp == "") { hp = "inherit"; }

    request = $.ajax({
      url: '/api/' + level_url + '/' + level_id,
      type: "PUT",
      cache: false,
      data: { homepage: hp },
      dataType: "json"
    });

    request.done(function(data) {
      var level = data.organization || data.branch || data.department;
      if (level.options.homepage) {
        $('span#homepage_inherited').hide();
        var msg = "OK! Lagret.";
      } else {
        $('span#homepage_inherited').show();
        $('input#homepage').val(level.options_inherited.homepage);
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
      url: '/api/' + level_url + '/' + level_id,
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
