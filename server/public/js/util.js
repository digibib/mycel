"use strict";

function Util() {}

Util.createStatusBar = function(data) {
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

  Util.createStatusCell = function(status, ts, onlineSince) {
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