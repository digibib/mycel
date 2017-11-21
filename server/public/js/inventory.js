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



  const initializeTable = function() {
    $('#inventory_table').DataTable( {
      language: {
        search: 'Søk',
        processing: 'Vennligst vent...',
      },
      order: [ [2, "asc"], [3, "asc"] ],
      paging: false,
      processing: true,
      deferRender: true,
      autoWidth: false,
      //fixedHeader: true,
      info: false,
      dom: 'fBrtip',
      buttons: [
        {
          extend: 'csvHtml5',
          exportOptions: {
            rows: ':visible'
          }
        }
      ],
      columns: [
        { data: "status", className: 'status', orderData: 6},
        { data: "downtimes", visible: true},
        { data: "branch_name"},
        { data: "name"},
        { data: "specs.cpu_family", defaultContent: "-"},
        { data: "specs.ram", defaultContent: "-"},
        { data: "hwaddr", defaultContent: "-"},
        { data: "status", visible: false}
      ],

      // adding class to the TR for filtering by status. There are probably better
      // ways to do this, but it works.
      "rowCallback": function( row, data, index ) {
        $(row).removeClass('occupied available unseen disconnected')
        $(row).addClass(data.status)
      },

      "columnDefs": [
        {
          targets: '_all',
          searchable: true
        },

        // adding class to the TR for filtering by branch. There are probably better
        // ways to do this, but it works.
        {
          "targets": [2],
          "createdCell": function (td, cellData, rowData, row, col) {
            $(td).parent().addClass(cellData)
          }
        },

        { // render status title and icon
          render: function ( data, type, row ) {
            let icon, title
            switch(data) {
              case 'occupied':
              icon = '/img/pc_green.png'
              title = 'Opptatt&#013;Online siden: ' + new Date(row['online_since']).toLocaleString('nb')
              break;
              case 'available':
              icon = '/img/pc_blue.png'
              title = 'Ledig&#013;Online siden: ' + new Date(row['online_since']).toLocaleString('nb')
              break;
              case 'disconnected':
              icon = '/img/pc_red.png'
              title = 'Sist sett ' + new Date(row['ts']).toLocaleString('nb')
              break;
              default:
              icon = '/img/pc_black.png'
              title = 'Aldri sett'
            }

            const link = "<a href='/admin?client_id=" + row['id'] + "'>"
            return link + "<img src=" + icon + " title='" + title + "'>" + "</a>"
          },

          targets: 0, orderable: true
        },
        { // render client title
          render: function ( data, type, row ) {
            return "<div title='" + row['title'] + "'>" + data + "</div>"
          },

          targets: 3, orderable: true
        },
        { // render downtime series into statusbar
          render: function ( data, type, row ) {
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
          },
          targets: 1, orderable: false
        }
      ]
    });
  }


  initializeTable()

  const cb = function() {
    updatePage()
    const table = $('#inventory_table').DataTable()
    setInterval( function () {
      table.ajax.reload(updatePage)
    }, 5 * 60 * 1000);
  }

  $('#inventory_table').DataTable().ajax.url('/api/client_specs').load(cb)
})
