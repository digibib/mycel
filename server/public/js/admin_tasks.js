"use strict";


$(function() {


  $("#branch_selector").change(function() {
    var branchID = $(this).val();
    $(".clients, .depts").prop("disabled", true).prop("hidden", true);
    $(".branch-" + branchID).prop("disabled", false).prop("hidden", false);
    $("#client_selector .branch-" + branchID).first().prop("selected", true);
    $("#client_selector").change();
  });


  $("#client_selector").change(function() {
    var clientID = $(this).val();
    var client = $("#" + clientID);
    var form = $("#edit_client_form")

    form.find("#name").val(client.data("name"));
    form.find("#hwaddr").val(client.data("hwaddr"));
    form.find("#ipaddr").val(client.data("ipaddr"))

    form.find("#shorttime").prop("checked", client.data("shorttime"));
    form.find("#test").prop("checked", client.data("test"));
    form.find("#client_screen_res option[value=" + client.data("screen_resolution_id") + "]").prop("selected", true);

    form.find("#client_branch_selector option[value=" + client.data("branch_id") + "]").prop("selected", true);
    form.find("#client_dept_selector option[value=" + client.data("department_id") + "]").prop("selected", true);
  });


  $("#client_branch_selector").change(function() {
    var branchID = $(this).val();
    $("#client_dept_selector .depts").prop("disabled", true).prop("hidden", true);
    $("#client_dept_selector .branch-" + branchID).prop("disabled", false).prop("hidden", false).first().prop("selected", true);
  });

  $("#request_selector").change(function() {
    var requestID = $(this).val();
    var request = $("#request-" + requestID);
    var form = $("#add_client_form");

    form.find("#name").val("");
    form.find("#request_id").val(requestID);
    form.find("#hwaddr").val(request.data("hwaddr"));
    form.find("#ipaddr").val(request.data("ipaddr"));

    form.find("#shorttime").prop("checked", false);
    form.find("#test").prop("checked", false);
    form.find("#client_screen_res option[value='1']").prop("selected", true);

    //form.find("#client_branch_selector option[value=" + client.data("branch_id") + "]").prop("selected", true);
    //form.find("#client_dept_selector option[value=" + client.data("department_id") + "]").prop("selected", true);
  });


  $(".edit_client_button").click(function() {
    var clientID = $(this).parent().parent().data("client_id");
    console.log(clientID);

  });

  $(".clients").prop("disabled", true).prop("hidden", true);
  $("#branch_selector option:first").prop("selected", true);
  $("#branch_selector").change();
  $("#request_selector option:first").prop("selected", true);


});
