"use strict";
/* global $ */

$(function() {
  const updatePage = function() {
    const $table = $('#inventory_table')
    const status = $('#status_selector option:selected').val()
    const branch = $('#branch_selector option:selected').val()

    let filter = 'tr'

    if (status !== 'all') {
      filter += '.' + status
    }

    if (branch !== 'all') {
      filter += '.' + branch
    }

    $table.find('tr:not(:first)').hide()
    $table.find(filter).show()
  }

  $('#status_selector, #branch_selector').change(function() {
    updatePage()
  })

  $(document).on('click', 'button.users.add_time', function() {
    const $row = $(this).parents('tr');
    const userID = $(this).data('id') // fix

    const $minutesInput = $row.find('.nr.required')
    const minutesToAdd = parseInt($minutesInput.val(), 10)

    const $currentMinutes = $row.find('.current_minutes span')  //.data('unadjusted_minutes'), 10)
    const userMinutes = parseInt($currentMinutes.data('user_minutes'), 10)
    const userAdjust = parseInt($currentMinutes.data('adjust'), 10)

    if (!minutesToAdd > 0) {
      $row.find('.error').html('Ugyldig input').show().fadeOut(5000)
      return
    }

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

  })


  //$('#inventory_table').DataTable().ajax.url('/api/clients').load(cb)
  const createStatusCell = function(status, ts, onlineSince) {
    let icon, title
    switch(status) {
      case 'occupied':
      icon = '/img/pc_green.png'
      title = 'Opptatt&#013;Online siden: ' + new Date(onlineSince).toLocaleString('nb')
      break;
      case 'available':
      icon = '/img/pc_blue.png'
      title = 'Ledig&#013;Online siden: ' + new Date('onlineSince').toLocaleString('nb')
      break;
      case 'disconnected':
      icon = '/img/pc_red.png'
      title = 'Sist sett ' + new Date(ts).toLocaleString('nb')
      break;
      default:
      icon = '/img/pc_black.png'
      title = 'Aldri sett'
    }

    //const link = "<a href='/admin?client_id=" + row['id'] + "'>"
    return "<img src=" + icon + " title='" + title + "'>"
  }

  const createStatusBar = function(data) {
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

  const createUserCell = function(user) {
    return user ? "<span data-id='" + user.id + "'>" + user.name + "</span>" : ''
  }

  const createMinutesCell = function(client) {
    let result = ''

    if (client.user) {
      const departmentAdjust = parseInt($('#dept' + client.department_id).data('adjust'), 10)
      const adjust = client.user.type === "B" ? departmentAdjust : 0
      const userMinutes = client.user.minutes

      result = "<span data-user_minutes='" + userMinutes +"' data-adjust='" + adjust + "'>" + (userMinutes + adjust) + "</span>"
    }

    return result
  }

  const createAddMinutesButton = function(user) {
    return user ? '<input type="text" class="nr required"><button type="button" class="users add_time" data-id="'+ user.id +'">+</button>' : ''
  }


  const req = $.getJSON('/api/clients')
  req.done(function(data) {
    let rows = []

    data.clients
      .filter(function(client) {return client.branch_id == 2})
      .forEach(function(client) {
      let row = "<tr class='" + client.status + "' data-clientID='" + client.id + "'>"
      row += "<td>" + createStatusCell(client.status, client.ts, client.online_since) + "</td>"
      row += "<td>" + createStatusBar(client.offline_events) + "</td>"
      row += "<td>" + client.name + "</td>"
      row += "<td class='current_user'>" + createUserCell(client.user) + "</td>"
      row += "<td class='current_minutes'>" + createMinutesCell(client) + "</td>"
      //row += '<td><input type="text" class="nr required"></td>'
      row += "<td class='foo'>" + createAddMinutesButton(client.user) + "</td>"
      row += "<td><span class='info' /><span class='error' /></td>"
      row += "</tr>"

      rows.push(row)
    })

    $('#inventory_table').append(rows)
  })

  // update:  image, statusbar (sjeldnere?) bruker minutter (info)
  // husk: UI for gjestebruker
})
