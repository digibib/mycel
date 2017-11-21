"use strict";
/* global $ */



$(function() {
  const reloadRate = 60 * 1000

  const departmentIDs = $('.department_ids').map(function(){ return $(this).data('id')}).get()

  // sometimes the user is granted more minutes at the same time server times are
  // being updated, resulting in the minutes being overwritten with outdated info.
  // To counter this, the ajaxStop is being used as a semaphore.
  let userBeingUpdated = 0

  $(document).ajaxStop(function() {
    userBeingUpdated = 0
  })


  // handle branch selection (superadmin only)
  $('#branch_selector').change(function() {
    window.location.href = "/i?bid=" + $(this).find('option:selected').data('bid')
  })

  //////////////////////////////////////////////////////////////////////////////
  // ** handle add-guest-user events **

  $("button#adduser").on("click", function() {
    $('table.userform').toggle();
  });

  $("button#usercancel").on("click", function() {
    $('table.userform').hide();
  });

  $("button#userclear").on("click", function() {
    $('table.userform input').val('')
    $('table.userform select#user_age').prop('selectedIndex', 0)
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
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('td#user_form_response').find('span.error')
        .html("Brukeren finnes allerede! Velg et annet brukernavn.").show().fadeOut(5000);
    })
  });

  //////////////////////////////////////////////////////////////////////////////
  // ** handle find user events **
  const userDatalist = $('#user_datalist')

  $('#find_user_by_name').on('keypress', function(event) {
    if (event.which == 13) {
      // enter pressed
    }

    const query = $(this).val()
    userDatalist.empty()

    if (query.length > 0) {
      $.getJSON('/api/users/search/by_username/' + query).done(function(data) {
        data.forEach(function(elem) {
          userDatalist.append($("<option/>").html(elem.name))
        })
    })
    }
  })


  ///////////////////////////////////////////////////////////////////////////////


  $('.department_buttons button').click(function() {
    const $rows = $('#user_table tr')
    const deptID = $(this).val()

    $('.department_buttons button').removeClass('active')
    $(this).addClass('active')

    if (deptID) {
      $rows.each(function() { $(this).toggle($(this).data('deptid') == deptID)})
    } else {
      $rows.toggle(true)
    }
  })

  $(document).on('click', 'button.users.add_time', function() {
    const $row = $(this).parents('tr');
    const userID = $row.find('.current_user span').data('id')  //$(this).data('id') // fix

    const $minutesInput = $row.find('.nr.required')
    const minutesToAdd = parseInt($minutesInput.val(), 10)

    const $currentMinutes = $row.find('.current_minutes span')  //.data('unadjusted_minutes'), 10)
    const userMinutes = parseInt($currentMinutes.data('user_minutes'), 10)
    const userAdjust = parseInt($currentMinutes.data('adjust'), 10)

    if (isNaN(minutesToAdd) || minutesToAdd === 0) {
      $row.find('.error').html('Ugyldig input').show().fadeOut(5000)
      return
    }

    userBeingUpdated = userID

    const request = $.ajax({
      url: '/api/users/'+ userID,
      type: "PUT",
      data: {minutes: userMinutes + minutesToAdd},
      dataType: "json"
    });

    request.done(function(data) {
      $minutesInput.val('')
      $currentMinutes.data('user_minutes', data.user.minutes)
      $currentMinutes.html(data.user.minutes + userAdjust)

      $row.find('.info').html('ok').show().fadeOut(5000)
    })

    request.fail(function(jqXHR, textStatus, errorThrown) {
        $row.find('.error').html(jqXHR.responseText).show().fadeOut(5000);
     })
  })


  const createUserCell = function(user) {
    const userID = user ? user.id : ''
    const userName = user ? user.name : ''
    return "<span data-id='" + userID + "'>" + userName + "</span>"
  }

  const createMinutesCell = function(client) {
    let adjust = ''
    let userMinutes = ''

    if (client.user) {
      const departmentAdjust = parseInt($('#dept' + client.department_id).data('adjust'), 10)
      adjust = client.user.type === "B" ? departmentAdjust : 0
      userMinutes = client.user.minutes
    }

    return "<span data-user_minutes='" + userMinutes +"' data-adjust='" + adjust + "'>" + (userMinutes + adjust) + "</span>"
  }

  const req = $.getJSON('/api/clients')

  req.done(function(data) {
    let rows = []

    data.clients
    .filter(function(client) {return departmentIDs.includes(client.department_id)})
    .forEach(function(client) {
      const hidden = client.user ? '' : ' hidden'

      let row = "<tr class='" + client.status + "' data-clientID='" + client.id + "' data-deptID='" + client.department_id + "'>"
      row += "<td class='status_client'>" + Util.createStatusCell(client.status, client.ts, client.online_since) + "</td>"
      row += "<td class='status_bar'>" + Util.createStatusBar(client.offline_events) + "</td>"
      row += "<td>" + client.name + "</td>"
      row += "<td class='current_user'>" + createUserCell(client.user) + "</td>"
      row += "<td class='current_minutes'>" + createMinutesCell(client) + "</td>"
      row += "<td class='edit_minutes'" + hidden + " ><input type='text' class='nr required'><button type='button' class='users add_time'>+</button></td>"
      row += "<td><span class='info' /><span class='error' /></td>"
      row += "</tr>"

      rows.push(row)
    })

    $('#user_table').append(rows)
  })

  req.fail(function() {
    $('#server_status').show()
  })


  const updateClientRow = function($row, client) {
    $row.find('.current_user').html(createUserCell(client.user))
    $row.find('.current_minutes').html(createMinutesCell(client))
  }


  const reloadClientData = function() {
    $('#ajax_spinner').show()

    $.getJSON('/api/clients').done(function(data) {
      data.clients
      .filter(function(client) {return departmentIDs.includes(client.department_id)})
      .forEach(function(client) {
        const $row = $('#user_table').find("[data-clientid='" + client.id + "']");
        const currentUserID = parseInt($row.find('.current_user span').data('id'), 10)
        const userID = client.user ? parseInt(client.user.id, 10) : ''

        if (userBeingUpdated === userID) {
          return
        }

        if (currentUserID && !userID) {
          $row.find('.info').html('logget av').show().fadeOut(5000);
        } else if (!currentUserID && userID) {
          $row.find('.info').html('logget på').show().fadeOut(5000);
        } else if ((currentUserID && userID) && (currentUserID !== userID)) {
          $row.find('.info').html('brukerbytte').show().fadeOut(5000);
        }

        $row.find('.current_user').html(createUserCell(client.user))
        $row.find('.current_minutes').html(createMinutesCell(client))
        $row.find('.edit_minutes').toggle(client.user != null)
      })

      $('#server_status').hide()
    }).fail(function(jqXHR, textStatus, errorThrown) {
        $('#server_status').show()
     }).always(function() {
       $('#ajax_spinner').hide()
     })
  }

  setInterval(reloadClientData, reloadRate)



})
