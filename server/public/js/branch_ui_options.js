// TODO change all # duplicates to .class
// TODO split this into common.js, department.js and branch.js when done
// read branch_id here at top

$(document).ready(function () {

  function getLevelURL(mainTab) {
    const levelType = mainTab.find('input[name="level_type"]:first').val();
    let levelURL = ''

    switch (levelType) {
      case "Branch":
        levelURL = "branches";
        break;
      case "Department":
        levelURL = "departments";
        break
      case "Organization":
        levelURL = "organization";
        break;
    }

    return levelURL
  }

  // key to the backup hash composed of levelType + levelID
  function getBackupKey(mainTab) {
    const levelID = mainTab.find('input[name="level_id"]:first').val();
    const levelURL = getLevelURL(mainTab)
    return levelURL + levelID
  }

  // ** global vars
  const mainTabs = $('div.maintab')
  const backups = {}

  mainTabs.each(function(index, tab) {
    const key = getBackupKey($(this))

    let backup = new Object();
    backup.homepage = $(this).find('input[name="homepage"]:first').val();
    backup.al = $(this).find('input[name="age_lower"]:first').val();
    backup.ah = $(this).find('input[name="age_higher"]:first').val();

    backups[key] = backup
  })

  //var backup = new Object();
  //backup.homepage = $('input[name="homepage"]').val();
  //backup.al = $('input[name="age_lower"]').val();
  //backup.ah = $('input[name="age_higher"]').val();

  // ** set input masks **

  $('input[name="user_minutes"]').setMask('999');
  $('input[name="age_lower"]').setMask('99');
  $('input[name="age_higher"]').setMask('99');
  $('input[name="minutes_limit"]').setMask('999');
  $('input[name="minutes_before_closing"]').setMask('99');

  // ** global functions and handles **

  $(':input').focus(function () {
    if ($(this).hasClass('inputmissing')) {
      $(this).removeClass('inputmissing');
    }
  });

  // ** options tabs handling **
  function setActiveUnitTabs(index) {
    mainTabs.each(function(i, tab) {
      $(this).find('li.active').removeClass('active');
      $(this).find('.tabs li').eq(index).addClass('active')

      $(this).find('.pane').hide();
      $(this).find('.pane:eq('+index+')').show();
    })
  }

  setActiveUnitTabs(0)

  $('.tabs li').on('click', function() {
    setActiveUnitTabs($(this).index())
  });

  function setActiveTabs(index) {
    $('.ubertabs li.active').removeClass('active');
    $('.ubertabs li').eq(index).addClass('active')

    $('.uberpane').hide();
    $('.uberpane:eq('+ index + ')').show();
  }

  setActiveTabs(0)

  $('.ubertabs li').on('click', function() {
    const index = $(this).index()
    setActiveTabs(index)
  });


  // ** handle opening-hours events **

  $(':input.chk').change(function () {
    const mainTab = $(this).closest('.maintab')

    if($(this).attr("checked"))
    {
      var id = $(this).attr("name").slice(0, -6);
      mainTab.find("[name="+id+"opens]").attr("disabled", "disabled").removeClass("inputmissing");
      mainTab.find("[name="+id+"closes]").attr("disabled", "disabled").removeClass("inputmissing");
    } else {
      var id = $(this).attr("name").slice(0, -6);
      mainTab.find("[name="+id+"opens]").removeAttr("disabled");
      mainTab.find("[name="+id+"closes]").removeAttr("disabled");
    }
  });

  $(':input.hour').setMask('29:59').keypress(function() {
    var currentMask = $(this).data('mask').mask;
    var newMask = $(this).val().match(/^2.*/) ? "23:59" : "29:59";
    if (newMask != currentMask) {
      $(this).setMask(newMask);
    }
  });

  $('button[name="hoursclear"]').on('click', function () {
    const mainTab = $(this).closest('.maintab')
    const key = getBackupKey(mainTab)
    let backup = backups[key]

    backup.ohcopy = mainTab.find('[name="change_hours_form"]:first').clone();
    mainTab.find('[name="change_hours_form"]:first')[0].reset();
    mainTab.find('input[name="minutes_before_closing"]:first').val('')
    mainTab.find(':input.hour').val('').removeClass("inputmissing");
    mainTab.find(':input.hour').removeAttr("disabled");
    mainTab.find(':input.chk').removeAttr('checked');
    mainTab.find(':input.nr').removeClass("inputmissing");
  });

  $('button[name="hourssave"]').on('click', function() {
    const mainTab = $(this).closest('.maintab');
    const levelID = mainTab.find('input[name="level_id"]:first').val();
    const levelURL = getLevelURL(mainTab)

    var missing = 0;
    mainTab.find('[name="oh_table"]').find('input.required:not(:disabled)').each(function () {
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
        url: '/api/' + levelURL + '/' + levelID,
        type: 'PUT',
        cache: false,
        data: {
              opening_hours: "inherit"
              },
        dataType: "json"
      });
    } else {
      var request = $.ajax({
        url: '/api/' + levelURL + '/' + levelID,
        type: 'PUT',
        cache: false,
        data: {
              opening_hours: {
              monday_opens: mainTab.find('input[name="monday_opens"]:first').val(),
              monday_opens: mainTab.find('input[name="monday_closes"]:first').val(),
              tuesday_opens: mainTab.find('input[name="tuesday_opens"]:first').val(),
              tuesday_closes: mainTab.find('input[name="tuesday_closes"]:first').val(),
              wednsday_opens: mainTab.find('input[name="wednsday_opens"]:first').val(),
              wednsday_closes: mainTab.find('input[name="wednsday_closes"]:first').val(),
              thursday_opens: mainTab.find('input[name="thursday_opens"]:first').val(),
              thursday_closes: mainTab.find('input[name="thursday_closes"]:first').val(),
              friday_opens: mainTab.find('input[name="friday_opens"]:first').val(),
              friday_closes: mainTab.find('input[name="friday_closes"]:first').val(),
              saturday_opens: mainTab.find('input[name="saturday_opens"]:first').val(),
              saturday_closes: mainTab.find('input[name="saturday_closes"]:first').val(),
              sunday_opens: mainTab.find('input[name="sunday_opens"]:first').val(),
              sunday_closes: mainTab.find('input[name="sunday_closes"]:first').val(),
              monday_closed: mainTab.find('input[name="monday_closed"]:first').is(':checked'),
              tuesday_closed: mainTab.find('input[name="tuesday_closed"]:first').is(':checked'),
              wednsday_closed: mainTab.find('input[name="wednsday_closed"]:first').is(':checked'),
              thursday_closed: mainTab.find('input[name="thursday_closed"]:first').is(':checked'),
              friday_closed: mainTab.find('input[name="friday_closed"]:first').is(':checked'),
              saturday_closed: mainTab.find('input[name="saturday_closed"]:first').is(':checked'),
              sunday_closed: mainTab.find('input[name="sunday_closed"]:first').is(':checked'),
              minutes_before_closing: mainTab.find('input[name="minutes_before_closing"]:first').val(),
              }},
        dataType: "json"
      });
    }


    request.done(function(data) {
      var level = data.organization || data.branch || data.department;
      mainTab.find('span[name="hours_error"]:first').hide();
      if (level.options.opening_hours) {
        mainTab.find('span[name="hours_info"]:first').html("OK! Lagret.").show().fadeOut(5000);
        mainTab.find('[name="change_hours_form"]:first').find('span.inherited').hide();
      } else {
        mainTab.find('span[name="hours_info"]:first').html("OK! Arver instillinger").show().fadeOut(5000);
        mainTab.find('[name="change_hours_form"]:first').find('span.inherited').show();
        $.each(level.options_inherited.opening_hours, function(k, v) {
          console.log("wat!")
          console.log(k)
          if (v == true) {
            mainTab.find('input[name="' + k + '":first]').attr('checked', true);
            mainTab.find('input[name="' + k.slice(0, -6) + 'opens":first]').attr('checked', true);
            mainTab.find('input[name="' + k.slice(0, -6) + 'closes":first]').attr('checked', true);
            //$('#'+k.slice(0,-6)+'opens').attr("disabled", "disabled");
            //$('#'+k.slice(0,-6)+'closes').attr("disabled", "disabled");
          } else {
            console.log("hmm")
            mainTab.find('input[name="' + k + '":first]').val(v);

            //$('input#'+k).val(v);
          }
        });
      }
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      const key = getBackupKey(mainTab)
      let backup = backups[key]

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
    const mainTab = $(this).closest('.maintab');
    const levelID = mainTab.find('input[name="level_id"]').val();
    const levelURL = getLevelURL(mainTab)

    var lower = $('input#age_lower').val();
    var higher = $('input#age_higher').val();
    if ((lower == "") && (higher == "")) {
      var age_data = { age_limit_lower: "inherit", age_limit_higher: "inherit" };
    } else {
      var age_data = { age_limit_lower: lower, age_limit_higher: higher};
    }

    request = $.ajax({
      url: '/api/' + levelURL + '/' + levelID,
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
      const key = getBackupKey(mainTab)
      let backup = backups[key]

      $('span#age_error').html(jqXHR.responseText).show().fadeOut(5000);
      $('#age_lower').val(backup.al);
      $('#age_higher').val(backup.ah);
    });

  });

  // ** handle time-limit events

  $('input[name="time_limit_no_limit"]').change(function () {
    if($(this).attr("checked"))
    {
      $('input#time_limit').attr("disabled", "disabled");
    } else {
      $('input#time_limit').removeAttr("disabled");
    }
  });

  $('button[name="time_save"]').on('click', function () {
    const mainTab = $(this).closest('.maintab')
    const levelID = mainTab.find('input[name="level_id"]').val();
    const levelURL = getLevelURL(mainTab)

    var time = mainTab.find('input[name="time_limit"]').val();
    if (time == "") { hp = "inherit"; }

    request = $.ajax({
      url: '/api/' + levelURL + '/' + levelID,
      type: "PUT",
      cache: false,
      data: {
            time_limit: time,
            time_limit_no_limit: mainTab.find('input[name="time_limit_no_limit"]').is(':checked')
            },
      dataType: "json"
    });

    request.done(function(data) {
      var level = data.organization || data.branch || data.department;
      if (level.options.time_limit || level.options.time_limit_no_limit) {
        mainTab.find('span[name="time_inherited"]').hide();
        var msg = "OK! Lagret.";
      } else {
        mainTab.find('span[name="time_inherited"]').show();
        mainTab.find('input[name="time_limit"]').val(level.options_inherited.time_limit);
        var msg = "OK! Arver instillinger";
      }
      mainTab.find('span[name="time_info"]').html(msg).show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      mainTab.find('span[name="time_error"]').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // ** handle shorttime-limit events

  $('button[name="shorttime_save"]').on('click', function () {
    const mainTab = $(this).closest('.maintab')
    const levelID = mainTab.find('input[name="level_id"]').val();
    const levelURL = getLevelURL(mainTab)


    var time = mainTab.find('input[name="shorttime_limit"]').val();
    if (time == "") { hp = "inherit"; }

    request = $.ajax({
      url: '/api/' + levelURL + '/' + levelID,
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
        mainTab.find('span[name="shorttime_inherited"]').hide();
        var msg = "OK! Lagret.";
      } else {
        mainTab.find('span[name="shorttime_inherited"]').show();
        mainTab.find('input[name="shorttime_limit"]').val(level.options_inherited.shorttime_limit);
        var msg = "OK! Arver instillinger";
      }
      mainTab.find('span[name="shorttime_info"]').html(msg).show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      mainTab.find('span[name="shorttime_error"]').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // ** handle save homepage
  $('button[name="homepagesave"]').on('click', function () {
    const mainTab = $(this).closest('.maintab')
    const levelID = mainTab.find('input[name="level_id"]').val();
    const levelURL = getLevelURL(mainTab)


    var hp = mainTab.find('input[name="homepage"]').val();
    if (hp == "") { hp = "inherit"; }

    request = $.ajax({
      url: '/api/' + levelURL + '/' + levelID,
      type: "PUT",
      cache: false,
      data: { homepage: hp },
      dataType: "json"
    });

    request.done(function(data) {
      var level = data.organization || data.branch || data.department;
      if (level.options.homepage) {
        mainTab.find('span[name="homepage_inherited"]').hide();
        var msg = "OK! Lagret.";
      } else {
        mainTab.find('span[name="homepage_inherited"]').show();
        mainTab.find('input[name="homepage"]').val(level.options_inherited.homepage);
        var msg = "OK! Arver instillinger";
      }
      mainTab.find('span[name="homepage_info"]').html(msg).show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      const key = getBackupKey(mainTab)
      let backup = backups[key]

      mainTab.find('span[name="homepage_error"]').html(jqXHR.responseText).show().fadeOut(5000);
      mainTab.find('[name="homepage"]').val(backup.homepage);
    });
  });

  // ** handle save printer
  $('button[name="printersave"]').on('click', function () {
    const mainTab = $(this).closest('.maintab');
    const levelID = mainTab.find('input[name="level_id"]').val();
    const levelURL = getLevelURL(mainTab)


    request = $.ajax({
      url: '/api/' + levelURL + '/' + levelID,
      type: "PUT",
      cache: false,
      data: { printeraddr: mainTab.find('input[name="printer"]').val() },
      dataType: "json"
    });

    request.done(function(data) {
      mainTab.find('span[name="printer_info"]').html("OK! Lagret.").show().fadeOut(5000);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      mainTab.find('span[name="printer_error"]').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });


});
