"use strict";

function Util() {}

const dateFormatter = new Intl.DateTimeFormat('no')

Util.createStatusBar = function(data, clientID, size = "small") {
    const periodStart = new Date(data.period_start)
    const periodDuration = data.period_duration

    const dayLabels = ['Søndag', 'Mandag', 'Tirsdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lørdag']
    let bar = '<a href="#" data-featherlight-loading="Vennligst vent..." data-featherlight="/client_stats?id='
    bar += clientID + '"><div class="statusbar ' + size +  ' ">'

    data.events.forEach(function(event) {
      const start = new Date(event.start)
      const end = new Date(event.end)

      const from = dayLabels[start.getDay()] + ' ' + dateFormatter.format(start)
      const to = dayLabels[end.getDay()] + ' ' + dateFormatter.format(end)

      const diffInSeconds = Math.abs(end - start) / 1000
      const days = Math.floor(diffInSeconds / 60 / 60 / 24)
      const hours = Math.floor(diffInSeconds / 60 / 60 % 24)
      const minutes = Math.floor(diffInSeconds / 60 % 60)

      let duration = days > 0 ? days + 'd ' : ''
      duration += hours > 0 ? hours + 't ' : ''
      duration += minutes + 'm '

      let klazz = event.type == 'offline' ? 'down' : 'occupied'

      bar += '<div class="' + klazz + '" '
      + 'style="left:' + ((start - periodStart) / periodDuration) * 100 + '%;width:' + (end - start) / periodDuration * 100  + '%" '
      + 'title="Fra: ' + from + '\nTil: ' + to + '\nVarighet: ' + duration + '">'
      + '</div>';
    })

    bar += '</div></a>'

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
      title = 'Ledig&#013;Online siden: ' + new Date(onlineSince).toLocaleString('nb')
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
