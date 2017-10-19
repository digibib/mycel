"use strict";

$(function() {
  $('#branch_selector').change(function() {
    let branchID = $(this).find(':selected').data('branchid')
    if (branchID != "0") {
      location.href = '/dep?id=' + branchID
    }
  })
})
