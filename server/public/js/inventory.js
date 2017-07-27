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
      order: [ 1, "asc" ],
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
        { data: "status", className: status, orderData: 6},
        { data: "branch_name"},
        { data: "name"},
        { data: "specs.cpu_family", defaultContent: "-"},
        { data: "specs.ram", defaultContent: "-"},
        { data: "hwaddr", defaultContent: "-"},
        { data: "status", visible: false}
      ],

      "columnDefs": [
        {
          targets: '_all',
          searchable: true
        },

        // adding classes to the TRs for filtering. There are probably better
        // ways to do this, but it works.
        {
          "targets": [0,1],
          "createdCell": function (td, cellData, rowData, row, col) {
            $(td).parent().addClass(cellData)
          }
        },

        {
          render: function ( data, type, row ) {
            let icon, title
            switch(data) {
              case 'occupied':
              icon = '/img/pc_green.png'
              title = 'Opptatt'
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
            return "<img src=" + icon + " title='" + title + "'>"
          },

          targets: 0, orderable: true
        }
      ]
    });
  }

  $('#branch_selector, #status_selector').val('all')
  initializeTable()
  $('#inventory_table').DataTable().ajax.url('/api/client_specs').load()
})
