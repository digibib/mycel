"use strict";


$(function() {

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








  const handleClient = function(client) {



  }

  const getImageTag = function(status) {
    let icon, title
    switch(status) {
      case 'occupied':
      icon = '/img/pc_green.png'
      title = 'Opptat'
      break;
      case 'available':
      icon = '/img/pc_blue.png'
      title = 'Ledig'
      break;
      case 'disconnected':
      icon = '/img/pc_red.png'
      title = 'Frakoblet'
      break;
      default:
      icon = '/img/pc_black.png'
      title = 'Aldri sett'
    }

    return "<image src='" + icon +  "' title='" + title  + "'>"
  }

  const getUptimeSeries = function(data) {
    const periodStart = new Date(data.period_start)
    const periodDuration = data.period_duration

    const dayLabels = ['Søndag', 'Mandag', 'Tirsdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lørdag']
    let bar = '<div class="statusbar">'

    data.events.forEach(function(event) {
      const start = new Date(event.start)
      const end = new Date(event.end)

      const from = dayLabels[start.getDay()] + ' ' + start.toLocaleTimeString('nb')
      const to = dayLabels[end.getDay()] + ' ' + end.toLocaleTimeString('nb')

      const diffInSeconds = Math.abs(end - start) / 1000
      const days = Math.floor(diffInSeconds / 60 / 60 / 24)
      const hours = Math.floor(diffInSeconds / 60 / 60 % 24)
      const minutes = Math.floor(diffInSeconds / 60 % 60)

      let duration = days > 0 ? days + 'd ' : ''
      duration += hours > 0 ? hours + 't ' : ''
      duration += minutes + 'm '

      bar += '<div class="down" '
      + 'style="left:' + ((start - periodStart) / periodDuration) * 100 + '%;width:' + (end - start) / periodDuration * 100  + '%" '
      + 'title="Fra: ' + from + '\nTil: ' + to + '\nVarighet: ' + duration + '">'
      + '</div>';
    })

    bar += '</div>'

    return bar
  }



  //  tr class="#{klass}" id="#{client.id}"
    //  td[style="width:34px"]: img src="#{image}" class="pc"
  //    td #{client.name}
  //    td[style="width:160px" class="td-user"]
  //      div class="toggle"
  //        #{user.name if client.occupied?}
  //    - adjust = 0
  //    - adjust = client.options_self_or_inherited['time_limit'].to_i - 60 if client.user and client.user.type_short === "B"
  //    td[style="width:34px" class="td-minutes"] #{user.minutes+adjust if client.occupied?}


//         td[style="width:160px"]
  //        span class="info"
  //        span class="error"


  const handleDep = function(department) {
    let rows = ''

    department.clients.forEach(function(client) {
      const userName = client.user ? client.user.name : ''
      let adjust = 0

      if (client.user && client.user.type.short === "B") {
        let timeLimit = client.options.time_limit || client.options_inherited.time_limit
        timeLimit && (adjust = parseInt(timeLimit) - 60)
      }

      const remainingTime = (client.user && client.user.minutes + adjust) || ''

      let foo = '<td></td>'
      let klazz = client.user ? 'toggle' : 'toggle hidden'
      if (client.user) {
        let id = "<input type='hidden' class='user_id' value='" + client.user.id + "'>"
        let minutes = "<input type='hidden' class='users minutes' value='" + client.user.minutes + "'>"
        let input = "<input type='text' class='nr required'>"
        let button = "<button type='button' class='users add_time'>+</button>"

        foo = '<td><div class="toggle">' + id + minutes + input + button + '</div></td>'
      }

      // tr has class 'occupied' available, etc. does it do anything?
      // tr id="client.id"
      // image has a class pc, probably intended for future use
      let row = '<tr id="' + client.id +  '">'
      row += '<td>' + getImageTag(client.status) + '</td>'
      row += '<td>' + getUptimeSeries(client.offline_events) + '</td>'
      row += '<td>' + client.name + '</td>'
      row += '<td class="td-user"><div class="toggle">' + userName + '</div></td>'
      row += '<td class="td-minutes">' + remainingTime + '</td>'
      //row += '<td>' + foo + '</td>'
      row += foo
      // add info
      row += '</tr>'

      rows += row
    })

    //alert(rows)
    $('.clients > tbody:last-child').append(rows)

  }


  const loadData = function(type) {
    $.getJSON('/api/branches/1?expand=true').done(function(data) {

      // handle branch

      data.branch.departments.forEach(function(department) {
        handleDep(department)
      })
    })

  }

  //alert("yo!")
  loadData()
})
