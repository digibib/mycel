"use strict";

$(function() {
  const data_series = $('#client_data').data('series')
  const bar = Util.createStatusBar(data_series, null, 'big')

  const status = $('#client_data').data('status')
  const ts = $('#client_data').data('ts')
  const onlineSince = $('#client_data').data('online_since')

  const statusImage = Util.createStatusCell(status, ts, onlineSince)

  $('#client_data').html(bar)
})
