"use strict";

$(function() {
  const data_series = $('#client_data').data('series')
  const bar = Util.createStatusBar(data_series, null, 'big')

  const status = $('#client_data').data('status')
  const ts = $('#client_data').data('ts')
  const onlineSince = $('#client_data').data('online_since')

  const statusImage = Util.createStatusCell(status, ts, onlineSince)

  $('#client_data').html(bar)

  $('.no_of_days_selector').on("change", function() {
    const clientID = $(this).find(':selected').data('clientid')
    const noOfDays = $(this).find(':selected').data('no_of_days')

    const url = "/client_stats?id=" + clientID + "&no_of_days=" + noOfDays

    $.featherlight(url, {
      beforeOpen: function() {$.featherlight.close()}
    })
  })

})
